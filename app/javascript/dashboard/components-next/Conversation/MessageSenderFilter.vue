<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  modelValue: { type: String, default: 'all' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const SENDER_KINDS = [
  { key: 'all', icon: 'i-lucide-messages-square' },
  { key: 'customer', icon: 'i-lucide-user-round' },
  { key: 'ai', icon: 'i-lucide-sparkles' },
  { key: 'agent', icon: 'i-lucide-headset' },
  { key: 'auto', icon: 'i-lucide-bot' },
];
</script>

<template>
  <div
    class="flex items-center gap-1.5 px-4 py-2 overflow-x-auto border-b border-n-weak bg-n-surface-1"
  >
    <button
      v-for="kind in SENDER_KINDS"
      :key="kind.key"
      type="button"
      class="inline-flex items-center gap-1.5 px-2.5 h-7 rounded-full text-xs whitespace-nowrap transition-colors outline outline-1"
      :class="
        modelValue === kind.key
          ? 'bg-n-brand/10 text-n-brand outline-n-brand/40 font-semibold'
          : 'text-n-slate-11 outline-n-weak hover:bg-n-alpha-2 font-medium'
      "
      @click="emit('update:modelValue', kind.key)"
    >
      <span class="size-3.5" :class="kind.icon" />
      {{ t(`CONVERSATION.SENDER_FILTER.${kind.key.toUpperCase()}`) }}
    </button>
  </div>
</template>
