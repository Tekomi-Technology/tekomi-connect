import { ref } from 'vue';

// Panels rendered inside the conversation sidebar, each listing the sidebar
// sections (see DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER) it shows.
export const CONVERSATION_SIDE_PANELS = Object.freeze({
  contact: ['crm_info', 'contact_attributes'],
  actions: [
    'conversation_actions',
    'conversation_participants',
    'conversation_info',
    'macros',
  ],
  history: ['previous_conversation', 'contact_notes', 'shared_files'],
  sales: ['deals', 'tickets', 'shopify_orders', 'linear_issues'],
});

export const DEFAULT_CONVERSATION_SIDE_PANEL = 'contact';

const activePanel = ref(DEFAULT_CONVERSATION_SIDE_PANEL);

export function useConversationSidePanel() {
  return { activePanel };
}
