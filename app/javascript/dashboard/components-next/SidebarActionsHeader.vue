<script setup>
import Button from './button/Button.vue';
defineProps({
  title: {
    type: String,
    required: true,
  },
  buttons: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['click', 'close']);

const handleButtonClick = button => {
  emit('click', button.key);
};
</script>

<template>
  <div
    class="flex items-center justify-between px-4 py-2 border-b border-n-weak h-12"
  >
    <div class="flex items-center justify-between gap-2 flex-1">
      <span class="font-medium text-sm text-n-slate-12">{{ title }}</span>
      <div class="flex items-center">
        <Button
          v-for="button in buttons"
          :key="button.key"
          v-tooltip="button.tooltip"
          :icon="button.icon"
          ghost
          sm
          @click="handleButtonClick(button)"
        />
        <!-- Same collapse toggle as the conversation list; on phones the panel is an overlay, so it closes. -->
        <Button
          v-tooltip.left="$t('CONVERSATION.SIDEBAR.COLLAPSE_PANEL')"
          icon="i-lucide-chevron-right"
          slate
          xs
          faded
          class="hidden ms-1 !rounded-full md:inline-flex rtl:rotate-180"
          @click="$emit('close')"
        />
        <Button
          v-tooltip="$t('GENERAL.CLOSE')"
          icon="i-lucide-x"
          ghost
          sm
          class="md:hidden"
          @click="$emit('close')"
        />
      </div>
    </div>
  </div>
</template>
