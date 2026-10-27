<script setup>
import { computed, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import VipBadge from 'dashboard/components-next/Contacts/VipBadge.vue';
import ConversationAssignMenu from 'dashboard/components-next/Conversation/ConversationAssignMenu.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import wootConstants from 'dashboard/constants/globals';
import { useConversationRoutePath } from 'dashboard/composables/useConversationRoutePath';
import {
  DEFAULT_CONVERSATION_SIDE_PANEL,
  useConversationSidePanel,
} from 'dashboard/composables/useConversationSidePanel';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAiPanel } from 'dashboard/composables/useAiPanel';
import { useMessageFilter } from 'dashboard/composables/useMessageFilter';
import { SENDER_KINDS } from 'dashboard/components-next/message/helpers/senderKind';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useMapGetter } from 'dashboard/composables/store';
import { getSenderDisplayName } from 'dashboard/helper/crmDisplayHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);

const SINGLE_ROW_MIN_WIDTH = 840;
const FULL_LABELS_MIN_WIDTH = 520;
const isSingleRow = computed(() => width.value >= SINGLE_ROW_MIN_WIDTH);
const isCompact = computed(
  () => width.value > 0 && width.value < FULL_LABELS_MIN_WIDTH
);
const { isAWebWidgetInbox } = useInbox();
const { uiSettings, updateUISettings } = useUISettings();
const { activePanel } = useConversationSidePanel();
const { isAiAvailable } = useAiPanel();
const { senderKindFilter } = useMessageFilter();

const messageFilters = computed(() => [
  { key: 'all', label: t('CONVERSATION.MESSAGE_FILTER.ALL') },
  {
    key: SENDER_KINDS.CUSTOMER,
    label: t('CONVERSATION.MESSAGE_FILTER.CUSTOMER'),
  },
  { key: SENDER_KINDS.AI, label: t('CONVERSATION.MESSAGE_FILTER.AI') },
  { key: SENDER_KINDS.AGENT, label: t('CONVERSATION.MESSAGE_FILTER.AGENT') },
  { key: SENDER_KINDS.AUTO, label: t('CONVERSATION.MESSAGE_FILTER.AUTO') },
]);

const currentUser = useMapGetter('getCurrentUser');

const currentChat = computed(() => store.getters.getSelectedChat);

const chatMetadata = computed(() => props.chat.meta);

const { buildConversationListPath } = useConversationRoutePath();
const backButtonUrl = computed(() => buildConversationListPath());

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);
const currentContactDisplayName = computed(() =>
  getSenderDisplayName(currentContact.value)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const assignee = computed(() => props.chat.meta?.assignee);
const assigneeType = computed(() => props.chat.meta?.assignee_type || 'User');
const team = computed(() => props.chat.meta?.team);
const isResolved = computed(
  () => props.chat.status === wootConstants.STATUS_TYPE.RESOLVED
);
const isAssignedToMe = computed(
  () =>
    assigneeType.value === 'User' && assignee.value?.id === currentUser.value.id
);
const isAiHandling = computed(
  () =>
    props.chat.status === wootConstants.STATUS_TYPE.PENDING ||
    (assignee.value && assigneeType.value === 'AgentBot')
);

const statusPill = computed(() => {
  if (isResolved.value) {
    return {
      label: t('CONVERSATION.HEADER.STATUS_PILL.RESOLVED'),
      class: 'bg-n-slate-3 text-n-slate-11 [&>span]:bg-n-slate-9',
    };
  }
  if (isAiHandling.value) {
    return {
      label: t('CONVERSATION.HEADER.STATUS_PILL.AI'),
      class: 'bg-n-iris-3 text-n-iris-11 [&>span]:bg-n-iris-9',
    };
  }
  if (isAssignedToMe.value) {
    return {
      label: t('CONVERSATION.HEADER.STATUS_PILL.MINE'),
      class: 'bg-n-teal-3 text-n-teal-11 [&>span]:bg-n-teal-9',
    };
  }
  if (assignee.value) {
    return {
      label: t('CONVERSATION.HEADER.STATUS_PILL.ASSIGNED'),
      class: 'bg-n-blue-3 text-n-blue-11 [&>span]:bg-n-blue-9',
    };
  }
  return {
    label: t('CONVERSATION.HEADER.STATUS_PILL.UNASSIGNED'),
    class:
      'bg-n-amber-3 text-n-amber-11 ring-1 ring-inset ring-n-amber-7 [&>span]:bg-n-amber-9',
  };
});

const assigneeText = computed(() =>
  assignee.value
    ? t('CONVERSATION.HEADER.ASSIGNEE', { name: assignee.value.name })
    : t('CONVERSATION.HEADER.NO_ASSIGNEE')
);

const showClaim = computed(() => !isResolved.value && !isAssignedToMe.value);

const claimConversation = async () => {
  await store.dispatch('assignAgent', {
    conversationId: props.chat.id,
    agentId: currentUser.value.id,
    assigneeType: 'User',
  });
  useAlert(t('CONVERSATION.CHANGE_AGENT'));
};

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

const isInfoPanelOpen = computed(() =>
  Boolean(uiSettings.value.is_contact_sidebar_open)
);
const isAiPanelOpen = computed(() =>
  Boolean(uiSettings.value.is_copilot_panel_open)
);

const openSidePanel = panel => {
  updateUISettings({
    is_contact_sidebar_open: panel === 'info',
    is_copilot_panel_open: panel === 'ai',
  });
};

const toggleInfoPanel = () =>
  openSidePanel(isInfoPanelOpen.value ? null : 'info');
const toggleAiPanel = () => openSidePanel(isAiPanelOpen.value ? null : 'ai');

useKeyboardEvents({ 'Alt+KeyO': { action: toggleInfoPanel } });

watch(
  () => props.chat.id,
  () => {
    activePanel.value = DEFAULT_CONVERSATION_SIDE_PANEL;
    senderKindFilter.value = 'all';
  }
);

const panelButtonClass = isActive =>
  isActive ? '!bg-n-teal-3 !text-n-teal-11' : '!text-n-slate-10';

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col w-full min-w-0 px-4 pt-3 pb-2 bg-white border-b border-n-weak dark:bg-n-solid-2"
  >
    <div
      class="flex items-center justify-between w-full min-w-0 gap-3"
      :class="isSingleRow ? 'flex-row' : 'flex-col'"
    >
      <div
        class="flex items-center justify-start max-w-full min-w-0"
        :class="isSingleRow ? 'flex-1' : 'w-full'"
      >
        <BackButton
          v-if="showBackButton"
          :back-url="backButtonUrl"
          class="me-2"
        />
        <div class="relative shrink-0">
          <Avatar
            :name="currentContact.name"
            :src="currentContact.thumbnail"
            :size="40"
            :status="currentContact.availability_status"
            hide-offline-status
          />
          <span
            v-if="inbox.channel_type"
            class="absolute grid rounded-full -bottom-0.5 -end-0.5 size-4 place-items-center bg-n-solid-1 ring-1 ring-n-weak"
          >
            <ChannelIcon :inbox="inbox" use-brand-icon class="size-3" />
          </span>
        </div>
        <div class="flex flex-col items-start min-w-0 ms-3 overflow-hidden">
          <div class="flex flex-row items-center max-w-full gap-2 p-0 m-0">
            <span
              class="text-sm font-bold tracking-tight truncate leading-tight text-n-slate-12"
            >
              {{ currentContactDisplayName }}
            </span>
            <VipBadge v-if="currentContact.vip" />
            <fluent-icon
              v-if="!isHMACVerified"
              v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
              size="14"
              class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
              icon="warning"
            />
            <span
              class="inline-flex items-center flex-shrink-0 gap-1 px-2 py-0.5 rounded-full text-[10.5px] font-semibold whitespace-nowrap"
              :class="statusPill.class"
            >
              <span class="rounded-full size-1.5" />
              {{ statusPill.label }}
            </span>
          </div>

          <div
            class="flex items-center gap-1 mt-0.5 overflow-hidden text-xs text-n-slate-11 text-ellipsis whitespace-nowrap"
          >
            <span class="truncate">{{ inbox.name }}</span>
            <span class="flex-shrink-0 rounded-full size-0.5 bg-n-slate-9" />
            <span class="truncate">{{ assigneeText }}</span>
            <template v-if="team">
              <span class="flex-shrink-0 rounded-full size-0.5 bg-n-slate-9" />
              <span class="truncate">{{ team.name }}</span>
            </template>
            <span class="flex-shrink-0 rounded-full size-0.5 bg-n-slate-9" />
            <button
              type="button"
              class="truncate text-xs text-n-slate-11 hover:text-n-slate-12 !p-0 cursor-pointer"
              @click="copyConversationId"
            >
              {{ `#${chat.id}` }}
            </button>
            <template v-if="isSnoozed">
              <span class="flex-shrink-0 rounded-full size-0.5 bg-n-slate-9" />
              <span class="font-medium text-n-amber-10">
                {{ snoozedDisplayText }}
              </span>
            </template>
          </div>
        </div>
      </div>
      <div
        class="flex flex-row items-center flex-shrink-0 gap-2"
        :class="isSingleRow ? 'justify-end' : 'justify-start w-full'"
      >
        <SLACardLabel
          v-if="hasSlaPolicyId"
          :chat="chat"
          show-extended-info
          :parent-width="width"
          class="hidden md:flex"
        />
        <NextButton
          v-if="showClaim"
          v-tooltip.bottom="isCompact ? t('CONVERSATION.HEADER.CLAIM') : ''"
          :label="isCompact ? '' : t('CONVERSATION.HEADER.CLAIM')"
          icon="i-lucide-user-round"
          teal
          sm
          class="!text-xs !font-semibold"
          @click="claimConversation"
        />
        <ConversationAssignMenu :chat="chat" :compact="isCompact" />
        <ResolveAction
          :conversation-id="chat.id"
          :status="chat.status"
          :compact="isCompact"
        />
        <span class="w-px h-4 mx-1 bg-n-weak" />
        <ConversationCallButton :inbox="inbox" :chat="currentChat" />
        <NextButton
          v-if="isAiAvailable"
          v-tooltip.bottom="t('CONVERSATION.HEADER.AI_PANEL')"
          icon="i-lucide-sparkles"
          ghost
          slate
          sm
          :class="panelButtonClass(isAiPanelOpen)"
          :aria-pressed="isAiPanelOpen"
          data-side-panel-toggle
          @click="toggleAiPanel"
        />
        <NextButton
          v-tooltip.bottom="t('CONVERSATION.HEADER.INFO_PANEL')"
          icon="i-lucide-panel-right"
          ghost
          slate
          sm
          :class="panelButtonClass(isInfoPanelOpen)"
          :aria-pressed="isInfoPanelOpen"
          data-side-panel-toggle
          @click="toggleInfoPanel"
        />
        <MoreActions :conversation-id="currentChat.id" />
      </div>
    </div>
    <div
      role="group"
      :aria-label="t('CONVERSATION.MESSAGE_FILTER.LABEL')"
      class="flex items-center gap-1 pt-2 mt-2.5 overflow-x-auto border-t border-n-weak"
    >
      <button
        v-for="filter in messageFilters"
        :key="filter.key"
        type="button"
        class="px-2.5 py-1 text-xs rounded-md whitespace-nowrap transition-colors"
        :class="
          senderKindFilter === filter.key
            ? 'font-bold bg-n-teal-2 text-n-teal-11 ring-1 ring-n-weak shadow-sm'
            : 'font-medium text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
        "
        :aria-pressed="senderKindFilter === filter.key"
        @click="senderKindFilter = filter.key"
      >
        {{ filter.label }}
      </button>
    </div>
  </div>
</template>
