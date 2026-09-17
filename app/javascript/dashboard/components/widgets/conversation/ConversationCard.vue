<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import Avatar from 'next/avatar/Avatar.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import MessagePreview from './MessagePreview.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  chat: { type: Object, required: true },
  currentContact: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  isActiveChat: { type: Boolean, default: false },
  showAssignee: { type: Boolean, default: false },
  showInboxName: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
});

const emit = defineEmits([
  'click',
  'contextmenu',
  'selectConversation',
  'deSelectConversation',
]);

const { t } = useI18n();
const hovered = ref(false);

const unreadCount = computed(() => props.chat.unread_count);
const hasUnread = computed(() => unreadCount.value > 0);
const lastMessageInChat = computed(() => getLastMessage(props.chat));

const voiceCallData = computed(() => {
  const last = lastMessageInChat.value;
  if (last?.content_type !== 'voice_call' || !last.call) {
    return { status: null, direction: null };
  }
  return {
    status: last.call.status,
    direction: last.call.direction === 'outgoing' ? 'outbound' : 'inbound',
  };
});

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !props.currentContact?.blocked
);

const isVip = computed(() =>
  (props.chat.labels ?? []).find(label =>
    String(label).toLowerCase().includes('vip')
  )
);

const visibleLabels = computed(() =>
  (props.chat.labels ?? [])
    .filter(label => String(label).toLowerCase() !== 'vip')
    .slice(0, 2)
);

const priorityPillClass = computed(() => {
  const priority = props.chat.priority;
  if (priority === 'urgent' || priority === 'high') {
    return 'bg-n-ruby-3 text-n-ruby-11';
  }
  if (priority === 'medium') return 'bg-n-alpha-2 text-n-brand';
  return 'bg-n-alpha-2 text-n-slate-11';
});

const showBottomRow = computed(() => {
  return (
    props.chat.priority ||
    isVip.value ||
    visibleLabels.value.length > 0 ||
    hasSlaPolicyId.value
  );
});

const messagePreviewClass = computed(() => {
  return [hasUnread.value ? 'font-medium text-n-slate-12' : 'text-n-slate-11'];
});

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, props.inbox.id);
  } else {
    emit('deSelectConversation', props.chat.id, props.inbox.id);
  }
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => onSelectConversation(value),
});

watch(
  () => props.chat.id,
  () => {
    hovered.value = false;
  }
);
</script>

<template>
  <div
    class="relative flex items-start w-full gap-3 cursor-pointer border-b border-n-weak hover:bg-n-alpha-1 group"
    :class="[
      compact ? 'p-3' : 'p-4',
      {
        'bg-[#4F46E5]/[0.05] hover:bg-[#4F46E5]/[0.07]': isActiveChat,
        'selected bg-n-slate-2': selected,
      },
    ]"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <span
      v-if="isActiveChat"
      class="absolute left-0 top-0 bottom-0 w-1 bg-[#4F46E5] rounded-r"
    />
    <div
      class="relative shrink-0"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <Avatar
        v-if="!hideThumbnail"
        :name="currentContact.name"
        :src="currentContact.thumbnail"
        :size="40"
        :status="currentContact.availability_status"
        hide-offline-status
      >
        <template #overlay="{ size }">
          <label
            v-if="hovered || selected"
            class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px]"
            :style="{ width: `${size}px`, height: `${size}px` }"
            @click.stop
          >
            <Checkbox v-model="selectedModel" />
          </label>
        </template>
      </Avatar>
    </div>
    <div class="flex-1 min-w-0">
      <div class="flex items-start justify-between gap-2">
        <div class="flex items-center gap-1.5 min-w-0">
          <h4
            class="text-sm truncate text-n-slate-12"
            :class="hasUnread ? 'font-semibold' : 'font-medium'"
          >
            {{ currentContact.name }}
          </h4>
          <span
            v-if="hasUnread"
            class="rounded-full bg-[#4F46E5] size-2 shrink-0"
            :title="String(unreadCount)"
          />
        </div>
        <div class="flex items-center gap-1.5 shrink-0">
          <span
            v-if="showInboxName && inbox.name"
            class="text-xs text-n-slate-11 truncate max-w-24"
          >
            {{ inbox.name }}
          </span>
          <span class="text-xs font-normal text-n-slate-11">
            <TimeAgo
              :last-activity-timestamp="chat.timestamp"
              :created-at-timestamp="chat.created_at"
              :conversation-id="chat.id"
            />
          </span>
          <ChannelIcon
            v-if="inbox.channel_type"
            :inbox="inbox"
            use-brand-icon
            class="size-4 shrink-0"
          />
        </div>
      </div>
      <VoiceCallStatus
        v-if="voiceCallData.status"
        key="voice-status-row"
        :status="voiceCallData.status"
        :direction="voiceCallData.direction"
        :message-preview-class="messagePreviewClass"
      />
      <MessagePreview
        v-else-if="lastMessageInChat"
        key="message-preview"
        :message="lastMessageInChat"
        class="my-0.5 leading-5 min-w-0 text-[13px]"
        :class="messagePreviewClass"
      />
      <p
        v-else
        key="no-messages"
        class="text-n-slate-11 text-[13px] my-0.5 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
        :class="messagePreviewClass"
      >
        <fluent-icon
          size="16"
          class="-mt-0.5 align-middle inline-block text-n-slate-10"
          icon="info"
        />
        <span class="mx-0.5">
          {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
        </span>
      </p>
      <div
        v-if="showBottomRow"
        class="flex items-center justify-between gap-1 mt-1.5"
      >
        <div class="flex items-center gap-1.5 flex-wrap min-w-0">
          <SLACardLabel v-if="hasSlaPolicyId" :chat="chat" />
          <span
            v-if="chat.priority"
            class="px-2 py-0.5 rounded-full text-[11px] font-semibold capitalize flex items-center gap-1"
            :class="priorityPillClass"
          >
            <span
              v-if="chat.priority === 'urgent' || chat.priority === 'high'"
              class="rounded-full bg-n-ruby-9 size-1.5"
            />
            {{ chat.priority }}
          </span>
          <span
            v-if="isVip"
            class="px-2 py-0.5 rounded-full text-[11px] font-semibold uppercase bg-[#4F46E5]/10 text-[#4F46E5]"
          >
            {{ isVip }}
          </span>
          <span
            v-for="label in visibleLabels"
            :key="label"
            class="px-2 py-0.5 rounded-full text-[11px] font-medium bg-n-alpha-2 text-n-slate-11 truncate max-w-28"
          >
            {{ label }}
          </span>
        </div>
        <div
          v-if="showAssignee || !assignee.name"
          class="flex items-center gap-1 text-xs text-n-slate-11 shrink-0"
        >
          <template v-if="assignee.name">
            <Avatar :name="assignee.name" :size="20" />
            <span class="hidden sm:inline truncate max-w-20">
              {{ assignee.name }}
            </span>
          </template>
          <template v-else>
            <span
              class="flex items-center justify-center rounded-full border border-dashed border-n-strong size-5 text-n-slate-10"
            >
              <span class="i-lucide-plus size-3" />
            </span>
            <span class="hidden sm:inline">
              {{ t('CHAT_LIST.ASSIGNEE_TYPE_TABS.unassigned') }}
            </span>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
