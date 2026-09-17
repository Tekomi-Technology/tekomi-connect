import camelcaseKeys from 'camelcase-keys';
import SavedViewsAPI from 'dashboard/api/savedViews';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { defineStore } from 'pinia';

const JSON_ATTRIBUTES = ['filters', 'sorts', 'fields', 'settings'];

const camelizeView = view =>
  camelcaseKeys(view, { deep: true, stopPaths: JSON_ATTRIBUTES });

const toRequestPayload = ({ pipelineId, viewType, groupBy, ...rest }) => ({
  saved_view: {
    ...rest,
    ...(pipelineId !== undefined && { pipeline_id: pipelineId }),
    ...(viewType !== undefined && { view_type: viewType }),
    ...(groupBy !== undefined && { group_by: groupBy }),
  },
});

export const useSavedViewsStore = defineStore('savedViews', {
  state: () => ({
    records: [],
    uiFlags: { isFetching: false, isSaving: false },
  }),

  getters: {
    getView: state => id => state.records.find(view => view.id === Number(id)),
  },

  actions: {
    async fetch(pipelineId) {
      this.records = [];
      this.uiFlags.isFetching = true;
      try {
        const { data } = await SavedViewsAPI.get(pipelineId);
        this.records = data.payload.map(camelizeView);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async create(view) {
      this.uiFlags.isSaving = true;
      try {
        const { data } = await SavedViewsAPI.create(toRequestPayload(view));
        const record = camelizeView(data);
        this.records.push(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isSaving = false;
      }
    },

    async update(id, attributes) {
      this.uiFlags.isSaving = true;
      try {
        const { data } = await SavedViewsAPI.update(
          id,
          toRequestPayload(attributes)
        );
        const record = camelizeView(data);
        this.records = this.records.map(view =>
          view.id === record.id ? record : view
        );
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.uiFlags.isSaving = false;
      }
    },

    async delete(id) {
      try {
        await SavedViewsAPI.delete(id);
        this.records = this.records.filter(view => view.id !== id);
      } catch (error) {
        throwErrorMessage(error);
      }
    },
  },
});
