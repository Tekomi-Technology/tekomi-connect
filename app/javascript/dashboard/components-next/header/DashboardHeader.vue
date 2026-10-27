<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import HeaderNotifications from './HeaderNotifications.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAiPanel } from 'dashboard/composables/useAiPanel';
import {
  isAConversationRoute,
  isAInboxViewRoute,
} from 'dashboard/helper/routeHelpers';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const { uiSettings, updateUISettings } = useUISettings();
const { isAiAvailable } = useAiPanel();

const searchQuery = ref('');

// The search page has its own search box with filters and recent searches.
const isOnSearchPage = computed(() => route.name === 'search');

const showAiButton = computed(
  () =>
    isAiAvailable.value &&
    !isAConversationRoute(route.name) &&
    !isAInboxViewRoute(route.name)
);
const isAiPanelOpen = computed(() =>
  Boolean(uiSettings.value.is_copilot_panel_open)
);
const toggleAiPanel = () => {
  updateUISettings({
    is_copilot_panel_open: !isAiPanelOpen.value,
    is_contact_sidebar_open: false,
  });
};

const onSearch = () => {
  const q = searchQuery.value.trim();
  if (!q) return;
  searchQuery.value = '';
  router.push({ name: 'search', query: { q } });
};
</script>

<template>
  <header
    class="flex items-center flex-shrink-0 gap-3 px-4 bg-white border-b h-14 md:px-6 border-n-weak dark:bg-n-solid-2"
  >
    <form
      v-if="!isOnSearchPage"
      class="flex items-center flex-1 min-w-0 gap-2 px-4 transition-all duration-150 ease-out rounded-full h-9 max-w-lg bg-n-alpha-2 outline outline-1 outline-n-weak focus-within:bg-white focus-within:outline-n-brand focus-within:ring-4 focus-within:ring-n-brand/10 dark:focus-within:bg-n-solid-1"
      role="search"
      @submit.prevent="onSearch"
    >
      <span class="flex-shrink-0 i-lucide-search size-4 text-n-slate-10" />
      <input
        v-model="searchQuery"
        type="search"
        class="reset-base w-full min-w-0 m-0 text-sm bg-transparent border-transparent shadow-none outline-none text-n-slate-12 placeholder:text-n-slate-10 hover:border-transparent focus:border-transparent focus:shadow-none"
        :placeholder="t('COMBOBOX.SEARCH_PLACEHOLDER')"
      />
    </form>
    <div class="flex items-center gap-2 ltr:ml-auto rtl:mr-auto">
      <ComposeConversation>
        <template #trigger="{ isOpen }">
          <button
            type="button"
            class="grid flex-shrink-0 text-white transition-all duration-150 ease-out rounded-full shadow-sm size-9 place-items-center bg-n-brand hover:brightness-110 active:scale-95"
            :class="{ 'brightness-110 ring-4 ring-n-brand/20': isOpen }"
            :title="t('NEW_CONVERSATION.TITLE')"
          >
            <span class="i-lucide-plus size-5" />
          </button>
        </template>
      </ComposeConversation>
      <button
        v-if="showAiButton"
        type="button"
        class="grid flex-shrink-0 transition-colors rounded-full size-9 place-items-center text-n-teal-11 hover:bg-n-alpha-2"
        :class="{ 'bg-n-teal-3': isAiPanelOpen }"
        :title="t('TEKOMI.COPILOT.TAB_COPILOT')"
        :aria-pressed="isAiPanelOpen"
        data-side-panel-toggle
        @click="toggleAiPanel"
      >
        <span class="i-lucide-sparkles size-5" />
      </button>
      <HeaderNotifications />
    </div>
  </header>
</template>
