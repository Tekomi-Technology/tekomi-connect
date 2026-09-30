<script setup>
import { ref, computed, provide, watch, onMounted } from 'vue';
import { useBreakpoints } from '@vueuse/core';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import CompanyAPI from 'dashboard/api/companies';
import ConversationItem from './ConversationItem.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { sortComparator } from 'dashboard/store/modules/conversations/helpers';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  filters: { type: Object, required: true },
  label: { type: String, default: '' },
  teamId: { type: [String, Number], default: 0 },
  conversationType: { type: String, default: '' },
  isOnExpandedLayout: { type: Boolean, default: false },
});

const store = useStore();
const { t } = useI18n();
const allChatList = useMapGetter('getAllStatusChats');
const conversationStats = useMapGetter('conversationStats/getStats');

const listRef = ref(null);
const isContextMenuOpen = ref(false);
provide('contextMenuElementTarget', listRef);
provide('toggleContextMenu', state => {
  isContextMenuOpen.value = state;
});

const breakpoints = useBreakpoints({
  lg: wootConstants.LARGE_SCREEN_BREAKPOINT,
});
const isLgScreen = breakpoints.greaterOrEqual('lg');
const showExpandedCards = computed(
  () => props.isOnExpandedLayout && isLgScreen.value
);

const companies = ref([]);
const isLoadingCompanies = ref(true);
const expandedIds = ref(new Set());
const loadedPages = ref({});
const loadingIds = ref(new Set());

const conversationsByCompany = computed(() => {
  const groups = {};
  allChatList.value(props.filters).forEach(conversation => {
    const companyId = conversation.meta?.sender?.company_id;
    if (!companyId) return;
    groups[companyId] = groups[companyId] || [];
    groups[companyId].push(conversation);
  });
  Object.values(groups).forEach(list =>
    list.sort((a, b) => sortComparator(a, b, props.filters.sortBy))
  );
  return groups;
});

const companyCount = id => conversationStats.value.companyCounts[id] || 0;

const canLoadMore = id =>
  (conversationsByCompany.value[id]?.length || 0) < companyCount(id);

const fetchCompanies = async () => {
  try {
    const all = [];
    let page = 1;
    for (;;) {
      const { data } = await CompanyAPI.get({ page });
      all.push(...data.payload);
      if (!data.payload.length || all.length >= data.meta.total_count) break;
      page += 1;
    }
    companies.value = all;
  } catch (error) {
    useAlert(t('CHAT_LIST.COMPANY_LIST.FETCH_ERROR'));
  } finally {
    isLoadingCompanies.value = false;
  }
};

const fetchCompanyConversations = async companyId => {
  const page = (loadedPages.value[companyId] || 0) + 1;
  loadingIds.value.add(companyId);
  try {
    await store.dispatch('fetchCompanyConversations', {
      ...props.filters,
      assigneeType: wootConstants.ASSIGNEE_TYPE.ALL,
      companyId,
      page,
    });
    loadedPages.value = { ...loadedPages.value, [companyId]: page };
  } catch (error) {
    useAlert(t('CHAT_LIST.FETCH_ERROR'));
  } finally {
    loadingIds.value.delete(companyId);
  }
};

const toggleCompany = companyId => {
  if (expandedIds.value.has(companyId)) {
    expandedIds.value.delete(companyId);
    return;
  }
  expandedIds.value.add(companyId);
  if (!loadedPages.value[companyId]) fetchCompanyConversations(companyId);
};

watch(
  () => [
    props.filters.status,
    props.filters.sortBy,
    props.filters.inboxId,
    props.filters.teamId,
    props.filters.labels?.join(),
    props.filters.conversationType,
  ],
  () => {
    loadedPages.value = {};
    expandedIds.value.forEach(fetchCompanyConversations);
  }
);

onMounted(fetchCompanies);
</script>

<template>
  <div
    ref="listRef"
    class="flex-1 min-h-0 overflow-y-auto"
    :class="{ '!overflow-hidden': isContextMenuOpen }"
  >
    <div v-if="isLoadingCompanies" class="flex justify-center my-4">
      <Spinner class="text-n-brand" />
    </div>
    <p
      v-else-if="!companies.length"
      class="p-4 text-sm text-center text-n-slate-11"
    >
      {{ $t('CHAT_LIST.COMPANY_LIST.EMPTY') }}
    </p>
    <div
      v-for="company in companies"
      :key="company.id"
      class="border-b border-n-weak"
    >
      <button
        class="flex items-center w-full gap-2 px-4 py-3 text-left hover:bg-n-alpha-1"
        @click="toggleCompany(company.id)"
      >
        <Icon
          :icon="
            expandedIds.has(company.id)
              ? 'i-lucide-chevron-down'
              : 'i-lucide-chevron-right'
          "
          class="size-4 text-n-slate-11 flex-shrink-0"
        />
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ company.name }}
        </span>
        <span class="text-xs text-n-slate-11 ms-auto">
          {{ companyCount(company.id) }}
        </span>
      </button>
      <div v-if="expandedIds.has(company.id)" class="border-t border-n-weak">
        <ConversationItem
          v-for="conversation in conversationsByCompany[company.id] || []"
          :key="conversation.id"
          :source="conversation"
          :label="label"
          :team-id="teamId"
          :conversation-type="conversationType"
          show-assignee
          :show-expanded="showExpandedCards"
        />
        <div
          v-if="loadingIds.has(company.id)"
          class="flex justify-center my-3"
        >
          <Spinner class="text-n-brand" />
        </div>
        <p
          v-else-if="!conversationsByCompany[company.id]?.length"
          class="px-4 py-3 text-xs text-n-slate-11"
        >
          {{ $t('CHAT_LIST.COMPANY_LIST.NO_CONVERSATIONS') }}
        </p>
        <button
          v-else-if="canLoadMore(company.id)"
          class="w-full px-4 py-2 text-xs font-medium text-n-blue-11 hover:bg-n-alpha-1"
          @click="fetchCompanyConversations(company.id)"
        >
          {{ $t('CHAT_LIST.COMPANY_LIST.LOAD_MORE') }}
        </button>
      </div>
    </div>
  </div>
</template>
