import { defineStore } from 'pinia';
import camelcaseKeys from 'camelcase-keys';
import AiAlertsAPI from 'dashboard/api/aiAlerts';

const normalize = value => camelcaseKeys(value || {}, { deep: true });

const sortAlerts = alerts =>
  [...alerts].sort(
    (left, right) =>
      new Date(right.lastSeenAt || right.createdAt).getTime() -
      new Date(left.lastSeenAt || left.createdAt).getTime()
  );

export const useAiAlertsStore = defineStore('aiAlerts', {
  state: () => ({
    records: [],
    meta: {
      currentPage: 1,
      perPage: 50,
      totalEntries: 0,
      totalPages: 0,
      unreadCount: 0,
    },
    uiFlags: {
      isFetching: false,
      isUpdating: false,
      isDeleting: false,
    },
  }),

  getters: {
    unreadRecords: state => state.records.filter(alert => !alert.readAt),
  },

  actions: {
    async fetch(params = {}) {
      this.uiFlags.isFetching = true;
      try {
        const { data } = await AiAlertsAPI.get(params);
        this.records = sortAlerts((data.data || []).map(normalize));
        this.meta = { ...this.meta, ...normalize(data.meta) };
      } catch (error) {
        this.records = [];
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async markRead(id, read = true) {
      this.uiFlags.isUpdating = true;
      try {
        const { data } = await AiAlertsAPI.markRead(id, read);
        this.upsert(normalize(data));
        this.meta.unreadCount = this.records.filter(alert => !alert.readAt).length;
      } finally {
        this.uiFlags.isUpdating = false;
      }
    },

    async markAllRead() {
      this.uiFlags.isUpdating = true;
      try {
        await AiAlertsAPI.markAllRead();
        this.records = this.records.map(alert => ({
          ...alert,
          readAt: alert.readAt || new Date().toISOString(),
        }));
        this.meta.unreadCount = 0;
      } finally {
        this.uiFlags.isUpdating = false;
      }
    },

    async remove(id) {
      this.uiFlags.isDeleting = true;
      try {
        await AiAlertsAPI.delete(id);
        this.records = this.records.filter(alert => alert.id !== id);
        this.meta.totalEntries = Math.max(0, this.meta.totalEntries - 1);
        this.meta.unreadCount = this.records.filter(alert => !alert.readAt).length;
      } finally {
        this.uiFlags.isDeleting = false;
      }
    },

    upsert(alert) {
      if (!alert?.id) return;

      const index = this.records.findIndex(record => record.id === alert.id);
      if (index === -1) this.records = sortAlerts([normalize(alert), ...this.records]);
      else this.records[index] = { ...this.records[index], ...alert };
    },

    onRealtimeCreated(data = {}) {
      const { aiAlert, unreadCount, count } = normalize(data);
      this.upsert(aiAlert);
      if (typeof unreadCount === 'number') this.meta.unreadCount = unreadCount;
      if (typeof count === 'number') this.meta.totalEntries = count;
    },

    onRealtimeUpdated(data = {}) {
      const { aiAlert, unreadCount, count } = normalize(data);
      this.upsert(aiAlert);
      if (typeof unreadCount === 'number') this.meta.unreadCount = unreadCount;
      if (typeof count === 'number') this.meta.totalEntries = count;
    },

    onRealtimeDeleted(data = {}) {
      const { aiAlert, unreadCount, count } = normalize(data);
      if (aiAlert?.id) this.records = this.records.filter(alert => alert.id !== aiAlert.id);
      if (typeof unreadCount === 'number') this.meta.unreadCount = unreadCount;
      if (typeof count === 'number') this.meta.totalEntries = count;
    },

    onRealtimeMarkedRead(data = {}) {
      const { unreadCount } = normalize(data);
      this.records = this.records.map(alert => ({
        ...alert,
        readAt: alert.readAt || new Date().toISOString(),
      }));
      this.meta.unreadCount = typeof unreadCount === 'number' ? unreadCount : 0;
    },
  },
});
