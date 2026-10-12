import { defineStore } from 'pinia';
import TekomiPromptsAPI from 'dashboard/api/tekomi/prompts';

export const useTekomiPromptsStore = defineStore('tekomiPrompts', {
  state: () => ({
    records: [],
    selected: null,
    uiFlags: {
      isFetchingList: false,
      isFetchingItem: false,
      isSaving: false,
    },
  }),

  getters: {
    customizedCount: state =>
      state.records.filter(record => record.customized).length,
    groups: state => [...new Set(state.records.map(record => record.group))],
  },

  actions: {
    replaceRecord(detail) {
      const index = this.records.findIndex(
        record => record.key === detail.key
      );
      if (index !== -1) {
        this.records[index] = {
          ...this.records[index],
          customized: detail.customized,
          lines: detail.body.split('\n').length,
        };
      }
      this.selected = detail;
    },

    async fetch() {
      this.uiFlags.isFetchingList = true;
      try {
        const { data } = await TekomiPromptsAPI.get();
        this.records = data;
      } finally {
        this.uiFlags.isFetchingList = false;
      }
    },

    async fetchItem(key) {
      this.uiFlags.isFetchingItem = true;
      try {
        const { data } = await TekomiPromptsAPI.show(key);
        this.selected = data;
        return data;
      } finally {
        this.uiFlags.isFetchingItem = false;
      }
    },

    async save(key, body) {
      this.uiFlags.isSaving = true;
      try {
        const { data } = await TekomiPromptsAPI.save(key, body);
        this.replaceRecord(data);
        return data;
      } finally {
        this.uiFlags.isSaving = false;
      }
    },

    async restore(key) {
      this.uiFlags.isSaving = true;
      try {
        const { data } = await TekomiPromptsAPI.restore(key);
        this.replaceRecord(data);
        return data;
      } finally {
        this.uiFlags.isSaving = false;
      }
    },
  },
});
