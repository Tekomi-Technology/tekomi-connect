<script setup>
import { computed, onUnmounted } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConversationSidePanel } from 'dashboard/composables/useConversationSidePanel';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';
import { emitter } from 'shared/helpers/mitt';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

const props = defineProps({
  listUrl: { type: String, required: true },
});

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const { updateUISettings } = useUISettings();
const { activePanel } = useConversationSidePanel();

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const isCrmTicketsEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_TICKETS)
);

const PRIORITY_OPTIONS = [
  { value: null, key: 'NONE' },
  { value: CONVERSATION_PRIORITY.URGENT, key: 'URGENT' },
  { value: CONVERSATION_PRIORITY.HIGH, key: 'HIGH' },
  { value: CONVERSATION_PRIORITY.MEDIUM, key: 'MEDIUM' },
  { value: CONVERSATION_PRIORITY.LOW, key: 'LOW' },
];

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);

const currentChat = computed(() => store.getters.getSelectedChat);

const actionMenuItems = computed(() => {
  const items = [
    {
      icon: currentChat.value.pinned ? 'i-lucide-pin-off' : 'i-lucide-pin',
      label: currentChat.value.pinned
        ? t('CONVERSATION.CARD_CONTEXT_MENU.UNPIN')
        : t('CONVERSATION.CARD_CONTEXT_MENU.PIN'),
      action: 'toggle_pin',
      value: 'toggle_pin',
    },
    {
      icon: 'i-lucide-mail',
      label: t('CONVERSATION.CARD_CONTEXT_MENU.MARK_AS_UNREAD'),
      action: 'mark_unread',
      value: 'mark_unread',
    },
  ];

  if (isCrmTicketsEnabled.value) {
    items.push({
      icon: 'i-lucide-ticket',
      label: t('CONVERSATION.HEADER.TICKETS'),
      action: 'open_tickets',
      value: 'open_tickets',
    });
  }

  if (!currentChat.value.muted) {
    items.push({
      icon: 'i-lucide-volume-off',
      label: t('CONTACT_PANEL.MUTE_CONTACT'),
      action: 'mute',
      value: 'mute',
    });
  } else {
    items.push({
      icon: 'i-lucide-volume-1',
      label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
      action: 'unmute',
      value: 'unmute',
    });
  }

  items.push({
    icon: 'i-lucide-share',
    label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
    action: 'send_transcript',
    value: 'send_transcript',
  });

  return items;
});

const menuSections = computed(() => [
  { items: actionMenuItems.value },
  {
    title: t('CONVERSATION.PRIORITY.TITLE'),
    items: PRIORITY_OPTIONS.map(option => ({
      icon: `i-woot-priority-${(option.value || 'empty').toLowerCase()}`,
      label: t(`CONVERSATION.PRIORITY.OPTIONS.${option.key}`),
      action: 'priority',
      value: `priority_${option.key}`,
      priority: option.value,
      isSelected: (currentChat.value.priority || null) === option.value,
    })),
  },
]);

const togglePin = async () => {
  try {
    await store.dispatch('toggleConversationPin', {
      conversationId: currentChat.value.id,
      pinned: !currentChat.value.pinned,
    });
  } catch (error) {
    useAlert(t('CONVERSATION.PIN_ERROR'));
  }
};

const markUnread = async () => {
  await store.dispatch('markMessagesUnread', { id: currentChat.value.id });
  router.push({ path: props.listUrl, query: route.query });
};

const openTickets = () => {
  activePanel.value = 'sales';
  updateUISettings({
    is_contact_sidebar_open: true,
    is_copilot_panel_open: false,
    is_conversation_analysis_panel_open: false,
  });
};

const assignPriority = (priority, label) => {
  const conversationId = currentChat.value.id;
  store.dispatch('setCurrentChatPriority', { priority, conversationId });
  store.dispatch('assignPriority', { conversationId, priority }).then(() => {
    useAlert(
      t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
        priority: label,
        conversationId,
      })
    );
  });
};

const handleActionClick = ({ action, priority, label }) => {
  toggleDropdown(false);

  if (action === 'toggle_pin') {
    togglePin();
  } else if (action === 'mark_unread') {
    markUnread();
  } else if (action === 'open_tickets') {
    openTickets();
  } else if (action === 'priority') {
    assignPriority(priority, label);
  } else if (action === 'mute') {
    store.dispatch('muteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
  } else if (action === 'unmute') {
    store.dispatch('unmuteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
  } else if (action === 'send_transcript') {
    toggleEmailModal();
  }
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <div
      v-on-clickaway="() => toggleDropdown(false)"
      class="relative flex items-center group"
    >
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleDropdown()"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :menu-sections="menuSections"
        class="mt-1 ltr:right-0 rtl:left-0 top-full w-56 max-h-[70vh]"
        @action="handleActionClick"
      />
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />
  </div>
</template>
