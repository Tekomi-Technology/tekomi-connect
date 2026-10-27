<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isReplyRestricted: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['setMode']);

const { t } = useI18n();

const activeMode = computed(() =>
  props.isReplyRestricted ? REPLY_EDITOR_MODES.NOTE : props.mode
);

const tabs = computed(() => [
  {
    mode: REPLY_EDITOR_MODES.REPLY,
    label: t('CONVERSATION.REPLYBOX.REPLY'),
    icon: 'i-lucide-reply',
    activeClass: 'bg-n-teal-3 text-n-teal-11',
    disabled: props.disabled || props.isReplyRestricted,
  },
  {
    mode: REPLY_EDITOR_MODES.NOTE,
    label: t('CONVERSATION.REPLYBOX.PRIVATE_NOTE'),
    icon: 'i-lucide-lock',
    activeClass: 'bg-n-amber-3 text-n-amber-11',
    disabled: props.disabled,
  },
]);
</script>

<template>
  <div role="tablist" class="flex items-center gap-2">
    <button
      v-for="tab in tabs"
      :key="tab.mode"
      type="button"
      role="tab"
      :aria-selected="activeMode === tab.mode"
      :disabled="tab.disabled"
      class="flex items-center gap-1.5 px-2.5 py-1 text-xs font-semibold rounded-md whitespace-nowrap transition-colors disabled:cursor-not-allowed disabled:opacity-60"
      :class="
        activeMode === tab.mode
          ? tab.activeClass
          : 'text-n-slate-11 hover:enabled:bg-n-alpha-2'
      "
      @click="emit('setMode', tab.mode)"
    >
      <Icon :icon="tab.icon" class="size-3.5" />
      {{ tab.label }}
    </button>
  </div>
</template>
