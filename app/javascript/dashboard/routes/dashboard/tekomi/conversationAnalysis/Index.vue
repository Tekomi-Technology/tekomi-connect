<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import ConversationAnalysesAPI from 'dashboard/api/conversationAnalyses';
import PageLayout from 'dashboard/components-next/tekomi/PageLayout.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import QualityReport from './QualityReport.vue';
import OpportunityList from './OpportunityList.vue';

const PER_PAGE = 25;
const PERIODS = ['7', '30', '90', 'all'];

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const accountId = useMapGetter('getCurrentAccountId');
const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');

const activeTab = ref(0);
const period = ref('30');
const inboxId = ref('');
const assigneeId = ref('');
const currentPage = ref(1);
const report = ref(null);
const opportunities = ref([]);
const totalCount = ref(0);
const isFetching = ref(false);

const tabs = computed(() => [
  { key: 'quality', label: t('CONVERSATION_ANALYSIS.REPORT.TABS.QUALITY') },
  {
    key: 'opportunities',
    label: t('CONVERSATION_ANALYSIS.REPORT.TABS.OPPORTUNITIES'),
  },
]);
const isQualityTab = computed(() => activeTab.value === 0);

const periodOptions = computed(() =>
  PERIODS.map(value => ({
    value,
    label:
      value === 'all'
        ? t('CONVERSATION_ANALYSIS.REPORT.ALL_TIME')
        : t('CONVERSATION_ANALYSIS.REPORT.LAST_DAYS', { days: value }),
  }))
);
const inboxOptions = computed(() => [
  { value: '', label: t('CONVERSATION_ANALYSIS.REPORT.ALL_INBOXES') },
  ...inboxes.value.map(inbox => ({
    value: String(inbox.id),
    label: inbox.name,
  })),
]);
const agentOptions = computed(() => [
  { value: '', label: t('CONVERSATION_ANALYSIS.REPORT.ALL_AGENTS') },
  ...agents.value.map(agent => ({
    value: String(agent.id),
    label: agent.available_name || agent.name,
  })),
]);

const filterParams = computed(() => ({
  since:
    period.value === 'all'
      ? undefined
      : Math.floor(Date.now() / 1000) - Number(period.value) * 86400,
  inbox_id: inboxId.value || undefined,
  assignee_id: assigneeId.value || undefined,
}));

const fetchData = async () => {
  isFetching.value = true;
  try {
    if (isQualityTab.value) {
      const { data } = await ConversationAnalysesAPI.getReport(
        filterParams.value
      );
      report.value = data.payload;
    } else {
      const { data } = await ConversationAnalysesAPI.getOpportunities({
        ...filterParams.value,
        page: currentPage.value,
      });
      opportunities.value = data.payload;
      totalCount.value = data.meta.count;
    }
  } catch {
    useAlert(t('CONVERSATION_ANALYSIS.REPORT.LOAD_ERROR'));
  } finally {
    isFetching.value = false;
  }
};

watch([activeTab, period, inboxId, assigneeId], () => {
  if (currentPage.value !== 1) {
    currentPage.value = 1;
    return;
  }
  fetchData();
});
watch(currentPage, fetchData);

const onTabChanged = tab => {
  activeTab.value = tabs.value.findIndex(item => item.key === tab.key);
};

const openConversation = displayId => {
  router.push(
    frontendURL(conversationUrl({ accountId: accountId.value, id: displayId }))
  );
};

onMounted(() => {
  store.dispatch('agents/get');
  fetchData();
});
</script>

<template>
  <PageLayout
    :header-title="t('CONVERSATION_ANALYSIS.REPORT.TITLE')"
    :show-assistant-switcher="false"
    :show-know-more="false"
    :is-fetching="isFetching"
    :show-pagination-footer="!isQualityTab && totalCount > PER_PAGE"
    :current-page="currentPage"
    :total-count="totalCount"
    :items-per-page="PER_PAGE"
    @update:current-page="page => (currentPage = page)"
  >
    <template #controls>
      <div class="flex flex-col gap-4 mb-6">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTab"
          @tab-changed="onTabChanged"
        />
        <div class="flex flex-wrap items-center gap-2">
          <Select v-model="period" :options="periodOptions" />
          <Select v-model="inboxId" :options="inboxOptions" />
          <Select v-model="assigneeId" :options="agentOptions" />
        </div>
      </div>
    </template>
    <template #body>
      <QualityReport
        v-if="isQualityTab && report"
        :report="report"
        @open-conversation="openConversation"
      />
      <OpportunityList
        v-else-if="!isQualityTab"
        :opportunities="opportunities"
        @open-conversation="openConversation"
      />
    </template>
  </PageLayout>
</template>
