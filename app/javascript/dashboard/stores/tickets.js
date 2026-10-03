import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import TicketsAPI from 'dashboard/api/tickets';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { defineStore } from 'pinia';

const REALTIME_REFRESH_DELAY = 1000;
const STAGE_PAGE_SIZE = 25;
let metaRefreshTimer = null;

const camelizeTicket = ticket =>
  camelcaseKeys(ticket, {
    deep: true,
    stopPaths: [
      'custom_attributes',
      'contact.custom_attributes',
      'contact.additional_attributes',
    ],
  });

const camelizeMeta = meta => camelcaseKeys(meta, { deep: true });

const buildBaseParams = ({ pipelineId, filters = [], sorts = [] }) => ({
  pipeline_id: pipelineId,
  payload: filters.length ? filterQueryGenerator(filters).payload : [],
  sorts,
});

const createInitialMeta = () => ({
  count: 0,
  currentPage: 1,
  hasMore: false,
  stageStats: [],
});

export { camelizeTicket };

export const useTicketsStore = defineStore('tickets', {
  state: () => ({
    records: [],
    meta: createInitialMeta(),
    stageMeta: {},
    baseParams: null,
    watchedTicket: null,
    pipelineId: null,
    requestToken: 0,
    uiFlags: {
      isFetching: false,
      isFetchingMore: false,
      isCreating: false,
      fetchingStageId: null,
    },
  }),

  actions: {
    startRequest(query) {
      this.pipelineId = query.pipelineId;
      this.baseParams = buildBaseParams(query);
      this.requestToken += 1;
      this.uiFlags.isFetching = true;
      return this.requestToken;
    },

    finishRequest(requestToken) {
      if (this.requestToken === requestToken) this.uiFlags.isFetching = false;
    },

    resetRecords() {
      this.records = [];
      this.meta = createInitialMeta();
      this.stageMeta = {};
    },

    async fetch(query) {
      const requestToken = this.startRequest(query);
      try {
        const { data } = await TicketsAPI.filter({
          ...this.baseParams,
          page: 1,
        });
        if (this.requestToken !== requestToken) return;
        this.records = data.payload.map(camelizeTicket);
        this.stageMeta = {};
        this.meta = camelizeMeta(data.meta);
      } catch (error) {
        if (this.requestToken !== requestToken) return;
        this.resetRecords();
        throwErrorMessage(error);
      } finally {
        this.finishRequest(requestToken);
      }
    },

    async fetchMore() {
      if (!this.meta.hasMore || this.uiFlags.isFetchingMore) return;
      const requestToken = this.requestToken;
      this.uiFlags.isFetchingMore = true;
      try {
        const { data } = await TicketsAPI.filter({
          ...this.baseParams,
          page: this.meta.currentPage + 1,
        });
        if (this.requestToken !== requestToken) return;
        this.appendRecords(data.payload);
        this.meta = camelizeMeta(data.meta);
      } catch (error) {
        throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetchingMore = false;
      }
    },

    async fetchKanban(query, stageIds) {
      const requestToken = this.startRequest(query);
      try {
        const responses = await Promise.all(
          stageIds.map(stageId =>
            TicketsAPI.filter({
              ...this.baseParams,
              stage_id: stageId,
              page: 1,
              per_page: STAGE_PAGE_SIZE,
            })
          )
        );
        if (this.requestToken !== requestToken) return;
        const metas = responses.map(({ data }) => camelizeMeta(data.meta));
        const stageStats = metas.flatMap(meta => meta.stageStats);
        this.records = responses.flatMap(({ data }) =>
          data.payload.map(camelizeTicket)
        );
        this.stageMeta = Object.fromEntries(
          metas.map((meta, index) => [stageIds[index], meta])
        );
        this.meta = {
          ...createInitialMeta(),
          count: stageStats.reduce((total, stat) => total + stat.count, 0),
          stageStats,
        };
      } catch (error) {
        if (this.requestToken !== requestToken) return;
        this.resetRecords();
        throwErrorMessage(error);
      } finally {
        this.finishRequest(requestToken);
      }
    },

    async fetchMoreInStage(stageId) {
      const stageMeta = this.stageMeta[stageId];
      if (!stageMeta?.hasMore || this.uiFlags.fetchingStageId) return;
      const requestToken = this.requestToken;
      this.uiFlags.fetchingStageId = stageId;
      try {
        const { data } = await TicketsAPI.filter({
          ...this.baseParams,
          stage_id: stageId,
          page: stageMeta.currentPage + 1,
          per_page: STAGE_PAGE_SIZE,
        });
        if (this.requestToken !== requestToken) return;
        this.appendRecords(data.payload);
        this.stageMeta[stageId] = camelizeMeta(data.meta);
      } catch (error) {
        throwErrorMessage(error);
      } finally {
        this.uiFlags.fetchingStageId = null;
      }
    },

    appendRecords(payload) {
      const loadedIds = new Set(this.records.map(ticket => ticket.id));
      this.records.push(
        ...payload
          .map(camelizeTicket)
          .filter(ticket => !loadedIds.has(ticket.id))
      );
    },

    async show(id) {
      try {
        const { data } = await TicketsAPI.show(id);
        return camelizeTicket(data);
      } catch (error) {
        return throwErrorMessage(error);
      }
    },

    watchTicket(ticket) {
      this.watchedTicket = ticket;
    },

    unwatchTicket() {
      this.watchedTicket = null;
    },

    async create(ticket) {
      this.uiFlags.isCreating = true;
      try {
        const { data } = await TicketsAPI.create({ ticket });
        const record = camelizeTicket(data);
        this.upsert(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isCreating = false;
      }
    },

    async update(ticket, changes) {
      this.upsert({ ...ticket, ...changes });
      try {
        const { data } = await TicketsAPI.update(ticket.id, {
          ticket: snakecaseKeys(changes, { deep: false }),
        });
        const record = camelizeTicket(data);
        this.upsert(record);
        return record;
      } catch (error) {
        this.upsert(ticket);
        return throwErrorMessage(error);
      }
    },

    async move(ticket, { stageId, afterId, position }) {
      this.upsert({ ...ticket, stageId, position });
      try {
        const { data } = await TicketsAPI.move(ticket.id, { stageId, afterId });
        const record = camelizeTicket(data);
        this.upsert(record);
        return record;
      } catch (error) {
        this.upsert(ticket);
        return throwErrorMessage(error);
      }
    },

    async delete(ticket) {
      this.discard(ticket.id);
      try {
        await TicketsAPI.delete(ticket.id);
      } catch (error) {
        this.upsert(ticket);
        throwErrorMessage(error);
      }
    },

    // Drops the ticket from the board only. The detail page keeps rendering the watched
    // record, which is not necessarily part of the board currently loaded.
    remove(id) {
      this.records = this.records.filter(ticket => ticket.id !== id);
      this.scheduleMetaRefresh();
    },

    // The ticket is gone for good, so the detail page has to let go of it too.
    discard(id) {
      if (this.watchedTicket?.id === id) this.watchedTicket = null;
      this.remove(id);
    },

    upsert(record) {
      if (this.watchedTicket?.id === record.id) this.watchedTicket = record;
      if (record.pipelineId !== this.pipelineId) {
        this.remove(record.id);
        return;
      }
      const index = this.records.findIndex(ticket => ticket.id === record.id);
      if (index === -1) this.records.push(record);
      else this.records[index] = record;
      this.scheduleMetaRefresh();
    },

    onRealtimeUpsert(data) {
      this.upsert(camelizeTicket(data));
    },

    onRealtimeDelete({ id }) {
      this.discard(id);
    },

    scheduleMetaRefresh() {
      clearTimeout(metaRefreshTimer);
      metaRefreshTimer = setTimeout(
        () => this.refreshMeta(),
        REALTIME_REFRESH_DELAY
      );
    },

    async refreshMeta() {
      if (!this.baseParams) return;
      const requestToken = this.requestToken;
      const { data } = await TicketsAPI.filter({
        ...this.baseParams,
        per_page: 1,
      });
      if (this.requestToken !== requestToken) return;
      const { count, stageStats } = camelizeMeta(data.meta);
      this.meta = { ...this.meta, count, stageStats };
    },
  },
});
