<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';

// The list header disappears together with the list, so the expand button is
// rendered as a floating control by the conversation view instead.
defineProps({
  floating: { type: Boolean, default: false },
});

const { uiSettings, updateUISettings } = useUISettings();

const isCollapsed = computed(() =>
  Boolean(uiSettings.value.is_conversation_list_collapsed)
);

const toggle = () => {
  updateUISettings({
    is_conversation_list_collapsed: !isCollapsed.value,
  });
};
</script>

<template>
  <Button
    v-tooltip.right="
      isCollapsed ? $t('CHAT_LIST.EXPAND_LIST') : $t('CHAT_LIST.COLLAPSE_LIST')
    "
    :icon="isCollapsed ? 'i-lucide-chevron-right' : 'i-lucide-chevron-left'"
    slate
    xs
    faded
    class="hidden flex-shrink-0 rounded-full md:inline-flex rtl:rotate-180"
    :class="
      floating
        ? 'absolute top-3 z-20 shadow-sm border border-n-weak/50 bg-n-solid-2/90 backdrop-blur-lg ltr:left-2 rtl:right-2'
        : 'ltr:mr-1 rtl:ml-1'
    "
    @click="toggle"
  />
</template>
