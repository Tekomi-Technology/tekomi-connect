<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';

const { uiSettings, updateUISettings } = useUISettings();

const isOpen = computed(() => uiSettings.value.is_contact_sidebar_open);

const toggle = () => {
  updateUISettings({
    is_contact_sidebar_open: !isOpen.value,
    is_copilot_panel_open: false,
    is_conversation_analysis_panel_open: false,
  });
};
</script>

<template>
  <Button
    v-tooltip.left="
      isOpen
        ? $t('CONVERSATION.SIDEBAR.COLLAPSE_PANEL')
        : $t('CONVERSATION.SIDEBAR.EXPAND_PANEL')
    "
    :icon="isOpen ? 'i-lucide-chevron-right' : 'i-lucide-chevron-left'"
    slate
    xs
    class="hidden absolute top-3 z-20 rounded-full border shadow-sm md:inline-flex ltr:right-2 rtl:left-2 rtl:rotate-180 bg-n-solid-2/90 backdrop-blur-lg border-n-weak/50"
    @click="toggle"
  />
</template>
