import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import DealsAPI from 'dashboard/api/deals';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { defineStore } from 'pinia';

const REALTIME_REFRESH_DELAY = 1000;
const STAGE_PAGE_SIZE = 25;
const CALENDAR_PAGE_SIZE = 100;
const UNDATED_FIELD = 'expected_close_date';
let metaRefreshTimer = null;

const camelizeDeal = deal =>
  camelcaseKeys(deal, {
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

export { camelizeDeal };

export const useDealsStore = defineStore('deals', {
  state: () => ({
    records: [],
    undatedRecords: [],
    meta: createInitialMeta(),
    stageMeta: {},
    baseParams: null,
    calendarField: null,
    watchedDeal: null,
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
    startRequest(query, extraParams = {}) {
      this.pipelineId = query.pipelineId;
      this.baseParams = { ...buildBaseParams(query), ...extraParams };
      this.requestToken += 1;
      this.uiFlags.isFetching = true;
      return this.requestToken;
    },

    finishRequest(requestToken) {
      if (this.requestToken === requestToken) this.uiFlags.isFetching = false;
    },

    resetRecords() {
      this.records = [];
      this.undatedRecords = [];
      this.meta = createInitialMeta();
      this.stageMeta = {};
    },

    async fetch(query) {
      this.calendarField = null;
      const requestToken = this.startRequest(query);
      try {
        const { data } = await DealsAPI.filter({ ...this.baseParams, page: 1 });
        if (this.requestToken !== requestToken) return;
        this.records = data.payload.map(camelizeDeal);
        this.undatedRecords = [];
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
        const { data } = await DealsAPI.filter({
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
      this.calendarField = null;
      const requestToken = this.startRequest(query);
      try {
        const responses = await Promise.all(
          stageIds.map(stageId =>
            DealsAPI.filter({
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
          data.payload.map(camelizeDeal)
        );
        this.undatedRecords = [];
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
        const { data } = await DealsAPI.filter({
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

    async fetchCalendar(query, { dateField, dateFrom, dateTo }) {
      this.calendarField = dateField;
      const requestToken = this.startRequest(query, {
        date_field: dateField,
        date_from: dateFrom,
        date_to: dateTo,
      });
      try {
        const records = [];
        let meta = createInitialMeta();
        let page = 1;
        let hasMore = true;
        while (hasMore) {
          // eslint-disable-next-line no-await-in-loop
          const { data } = await DealsAPI.filter({
            ...this.baseParams,
            page,
            per_page: CALENDAR_PAGE_SIZE,
          });
          if (this.requestToken !== requestToken) return;
          records.push(...data.payload.map(camelizeDeal));
          meta = camelizeMeta(data.meta);
          hasMore = meta.hasMore;
          page += 1;
        }
        const undatedResponse =
          dateField === UNDATED_FIELD
            ? await DealsAPI.filter({
                ...buildBaseParams(query),
                date_field: dateField,
                date_missing: true,
                per_page: CALENDAR_PAGE_SIZE,
              })
            : null;
        if (this.requestToken !== requestToken) return;
        this.records = records;
        this.undatedRecords =
          undatedResponse?.data.payload.map(camelizeDeal) || [];
        this.stageMeta = {};
        this.meta = meta;
      } catch (error) {
        if (this.requestToken !== requestToken) return;
        this.resetRecords();
        throwErrorMessage(error);
      } finally {
        this.finishRequest(requestToken);
      }
    },

    appendRecords(payload) {
      const loadedIds = new Set(this.records.map(deal => deal.id));
      this.records.push(
        ...payload.map(camelizeDeal).filter(deal => !loadedIds.has(deal.id))
      );
    },

    async show(id) {
      try {
        const { data } = await DealsAPI.show(id);
        return camelizeDeal(data);
      } catch (error) {
        return throwErrorMessage(error);
      }
    },

    watchDeal(deal) {
      this.watchedDeal = deal;
    },

    unwatchDeal() {
      this.watchedDeal = null;
    },

    async create(deal) {
      this.uiFlags.isCreating = true;
      try {
        const { data } = await DealsAPI.create({ deal });
        const record = camelizeDeal(data);
        this.upsert(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isCreating = false;
      }
    },

    async update(deal, changes) {
      this.upsert({ ...deal, ...changes });
      try {
        const { data } = await DealsAPI.update(deal.id, {
          deal: snakecaseKeys(changes, { deep: false }),
        });
        const record = camelizeDeal(data);
        this.upsert(record);
        return record;
      } catch (error) {
        this.upsert(deal);
        return throwErrorMessage(error);
      }
    },

    async move(deal, { stageId, afterId, position }) {
      this.upsert({ ...deal, stageId, position });
      try {
        const { data } = await DealsAPI.move(deal.id, { stageId, afterId });
        const record = camelizeDeal(data);
        this.upsert(record);
        return record;
      } catch (error) {
        this.upsert(deal);
        return throwErrorMessage(error);
      }
    },

    async delete(deal) {
      this.remove(deal.id);
      try {
        await DealsAPI.delete(deal.id);
      } catch (error) {
        this.upsert(deal);
        throwErrorMessage(error);
      }
    },

    remove(id) {
      if (this.watchedDeal?.id === id) this.watchedDeal = null;
      this.records = this.records.filter(deal => deal.id !== id);
      this.undatedRecords = this.undatedRecords.filter(deal => deal.id !== id);
      this.scheduleMetaRefresh();
    },

    upsert(record) {
      if (this.watchedDeal?.id === record.id) this.watchedDeal = record;
      if (record.pipelineId !== this.pipelineId) {
        this.remove(record.id);
        return;
      }
      const isUndated =
        this.calendarField === UNDATED_FIELD && !record.expectedCloseDate;
      const target = isUndated ? 'undatedRecords' : 'records';
      const other = isUndated ? 'records' : 'undatedRecords';
      this[other] = this[other].filter(deal => deal.id !== record.id);
      const index = this[target].findIndex(deal => deal.id === record.id);
      if (index === -1) this[target].push(record);
      else this[target][index] = record;
      this.scheduleMetaRefresh();
    },

    onRealtimeUpsert(data) {
      this.upsert(camelizeDeal(data));
    },

    onRealtimeDelete({ id }) {
      this.remove(id);
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
      const { data } = await DealsAPI.filter({
        ...this.baseParams,
        per_page: 1,
      });
      if (this.requestToken !== requestToken) return;
      const { count, stageStats } = camelizeMeta(data.meta);
      this.meta = { ...this.meta, count, stageStats };
    },
  },
});
