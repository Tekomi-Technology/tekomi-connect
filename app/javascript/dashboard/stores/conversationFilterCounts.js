import { defineStore } from 'pinia';
import ConversationApi from 'dashboard/api/inbox/conversation';

export const useConversationFilterCountsStore = defineStore(
  'conversationFilterCounts',
  {
    state: () => ({ filters: {}, labels: {}, teams: {}, folders: {} }),

    actions: {
      async fetch({ inboxId, conversationType }) {
        const { data } = await ConversationApi.filterCounts({
          inboxId,
          conversationType,
        });
        this.filters = data.filters || {};
        this.labels = data.labels || {};
        this.teams = data.teams || {};
        this.folders = data.folders || {};
      },
    },
  }
);
