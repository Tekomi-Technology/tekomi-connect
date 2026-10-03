<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { formatTime } from '@chatwoot/utils';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import RadialChart from 'dashboard/routes/dashboard/home/components/cards/RadialChart.vue';
import MiniStat from 'dashboard/routes/dashboard/home/components/cards/MiniStat.vue';
import ReportHeader from './components/ReportHeader.vue';
import MetricCard from './components/overview/MetricCard.vue';
import ConversationChartCard from './components/overview/ConversationChartCard.vue';
import SummaryTableCard from './components/overview/SummaryTableCard.vue';
import StatusBreakdownCard from './components/overview/StatusBreakdownCard.vue';
import ConversationHeatmapContainer from './components/heatmaps/ConversationHeatmapContainer.vue';
import ResolutionHeatmapContainer from './components/heatmaps/ResolutionHeatmapContainer.vue';
import { useReportsOverview } from './composables/useReportsOverview';

const PERIODS = ['week', 'month', 'quarter'];
const KEY = 'OVERVIEW_REPORTS.SUMMARY';

// Each CSV the page can export: [store action, file name prefix].
const DOWNLOADS = {
  conversations: ['downloadConversationsSummaryReports', 'conversation'],
  inbox: ['downloadInboxReports', 'inbox'],
  agent: ['downloadAgentReports', 'agent'],
  sla: ['slaReports/download', 'sla'],
};

const { t } = useI18n();
const store = useStore();

const {
  period,
  dimension,
  range,
  summary,
  slaMetrics,
  inboxSummary,
  agentSummary,
  statusData,
  isLoading,
  hasError,
  load,
} = useReportsOverview();

const activeMetric = ref('conversations');
const chartView = ref('inbox');

// The status split only counts conversations, so it pins that metric.
const selectMetric = metric => {
  activeMetric.value = metric;
  if (metric !== 'conversations' && chartView.value === 'status') {
    chartView.value = 'inbox';
  }
};

const chartViewModel = computed({
  get: () => chartView.value,
  set: value => {
    chartView.value = value;
    if (value === 'status') activeMetric.value = 'conversations';
  },
});

const resolutionRate = computed(() => {
  const { conversations_count: total, resolutions_count: resolved } =
    summary.value;
  return total ? Math.round((resolved / total) * 100) : 0;
});

const slaHitRate = computed(
  () => Number.parseFloat(slaMetrics.value.hitRate) || 0
);

const kpis = computed(() => [
  {
    key: 'conversations',
    icon: 'i-lucide-message-square-plus',
    value: summary.value.conversations_count,
  },
  {
    key: 'resolved',
    icon: 'i-lucide-circle-check-big',
    value: summary.value.resolutions_count,
    hint: t(`${KEY}.KPI.RESOLVED_HINT`, { rate: resolutionRate.value }),
  },
  {
    key: 'first_response',
    icon: 'i-lucide-timer',
    value: formatTime(summary.value.avg_first_response_time || 0),
  },
  {
    key: 'resolution_time',
    icon: 'i-lucide-hourglass',
    value: formatTime(summary.value.avg_resolution_time || 0),
  },
]);

const tileClass = key =>
  activeMetric.value === key
    ? 'bg-gradient-to-br from-n-brand/10 to-transparent ring-2 ring-n-brand/60 border-transparent shadow-[0_14px_32px_-14px_rgb(var(--teal-9)/0.7)] [transform:perspective(700px)_translateY(-4px)]'
    : 'bg-white dark:bg-n-solid-2 border-n-weak shadow-sm hover:shadow-md hover:[transform:perspective(700px)_rotateX(6deg)_translateY(-2px)]';

const download = name => {
  const [action, type] = DOWNLOADS[name];
  const { since, until } = range.value;
  store.dispatch(action, {
    from: since,
    to: until,
    fileName: generateFileName({ type, to: until }),
  });
};

const exportAll = () => Object.keys(DOWNLOADS).forEach(download);

onMounted(load);
</script>

<template>
  <ReportHeader
    is-live
    :header-title="$t('OVERVIEW_REPORTS.HEADER')"
    :header-description="t(`${KEY}.SUBTITLE`)"
  >
    <Button
      v-tooltip="t(`${KEY}.EXPORT_HINT`)"
      :label="t(`${KEY}.EXPORT`)"
      icon="i-lucide-download"
      size="sm"
      @click="exportAll"
    />
    <template #filters>
      <div
        class="flex items-center gap-1 p-1 border rounded-xl bg-n-alpha-1 border-n-weak"
      >
        <button
          v-for="option in PERIODS"
          :key="option"
          type="button"
          class="px-3 py-1 rounded-lg text-[13px] font-medium transition-all duration-200"
          :class="
            period === option
              ? 'bg-white shadow-sm text-n-brand dark:bg-n-solid-3'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="period = option"
        >
          {{ t(`${KEY}.PERIOD.${option.toUpperCase()}`) }}
        </button>
      </div>
      <button
        type="button"
        class="flex items-center gap-2 px-3 py-1.5 rounded-xl border border-n-weak text-[13px] text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1"
        :disabled="isLoading"
        @click="load"
      >
        <span class="rounded-full size-2 bg-n-teal-9" />
        {{ t(`${KEY}.REFRESH`) }}
        <span
          class="i-lucide-refresh-cw size-3.5"
          :class="{ 'animate-spin': isLoading }"
        />
      </button>
    </template>
  </ReportHeader>

  <div
    v-if="hasError"
    class="flex flex-col items-center gap-3 py-16 text-sm text-n-slate-11"
  >
    {{ t(`${KEY}.ERROR`) }}
    <button
      type="button"
      class="font-medium text-n-brand hover:underline"
      @click="load"
    >
      {{ t(`${KEY}.RETRY`) }}
    </button>
  </div>

  <template v-else>
    <div
      role="tablist"
      class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5"
    >
      <button
        v-for="kpi in kpis"
        :key="kpi.key"
        type="button"
        role="tab"
        :aria-selected="activeMetric === kpi.key"
        class="relative flex flex-col gap-2 p-4 overflow-hidden text-left border rounded-2xl transition-all duration-500 ease-out motion-reduce:transition-none"
        :class="tileClass(kpi.key)"
        @click="selectMetric(kpi.key)"
      >
        <span
          class="absolute inset-x-0 top-0 h-1 transition-transform duration-500 ease-out origin-left bg-n-brand"
          :class="activeMetric === kpi.key ? 'scale-x-100' : 'scale-x-0'"
        />
        <span class="flex items-start justify-between gap-2">
          <span
            class="text-[11px] font-semibold tracking-wide uppercase"
            :class="
              activeMetric === kpi.key ? 'text-n-brand' : 'text-n-slate-11'
            "
          >
            {{ t(`${KEY}.KPI.${kpi.key.toUpperCase()}`) }}
          </span>
          <span
            class="size-4 shrink-0 transition-colors duration-300"
            :class="[
              kpi.icon,
              activeMetric === kpi.key ? 'text-n-brand' : 'text-n-slate-10',
            ]"
          />
        </span>
        <span
          class="text-3xl font-semibold tracking-tight truncate text-n-slate-12 tabular-nums"
        >
          {{ kpi.value }}
        </span>
        <span v-if="kpi.hint" class="text-xs font-medium text-n-slate-11">
          {{ kpi.hint }}
        </span>
      </button>
      <router-link
        :to="{ name: 'sla_reports' }"
        class="relative flex flex-col gap-2 p-4 overflow-hidden bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2 transition-all duration-500 ease-out hover:shadow-md hover:[transform:perspective(700px)_rotateX(6deg)_translateY(-2px)] motion-reduce:transition-none"
      >
        <span class="flex items-start justify-between gap-2">
          <span
            class="text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
          >
            {{ t(`${KEY}.KPI.SLA`) }}
          </span>
          <span class="i-lucide-arrow-up-right size-4 shrink-0 text-n-slate-10" />
        </span>
        <span
          class="text-3xl font-semibold tracking-tight truncate text-n-slate-12 tabular-nums"
        >
          {{ slaMetrics.hitRate }}
        </span>
        <span
          class="text-xs font-medium"
          :class="
            slaMetrics.numberOfSLAMisses ? 'text-n-ruby-11' : 'text-n-teal-11'
          "
        >
          {{
            t(`${KEY}.KPI.SLA_HINT`, { count: slaMetrics.numberOfSLAMisses })
          }}
        </span>
      </router-link>
    </div>

    <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
      <ConversationChartCard
        v-model:view="chartViewModel"
        class="lg:col-span-8"
        :metric="activeMetric"
        :inbox-rows="inboxSummary"
        :agent-rows="agentSummary"
        :timeline="statusData?.timeline ?? []"
        :group-by="range.groupBy"
        :is-loading="isLoading && !statusData"
        @download="download"
      />

      <MetricCard
        class="lg:col-span-4"
        :header="t(`${KEY}.SLA.TITLE`)"
        :description="
          t(`${KEY}.SLA.DESCRIPTION`, {
            count: slaMetrics.numberOfConversations,
          })
        "
        icon="i-lucide-shield-check"
        :show-live-badge="false"
        body-class="flex flex-col w-full min-w-0 gap-4"
      >
        <template #control>
          <Button
            v-tooltip="t(`${KEY}.DOWNLOAD`)"
            sm
            slate
            faded
            icon="i-lucide-download"
            class="rounded-md"
            @click="download('sla')"
          />
        </template>
        <RadialChart
          :value="slaHitRate"
          :label="t(`${KEY}.SLA.LABEL`)"
          :height="220"
        />
        <div class="grid grid-cols-2 gap-3">
          <MiniStat
            :label="t(`${KEY}.SLA.BREACHES`)"
            :value="slaMetrics.numberOfSLAMisses"
            tone="ruby"
          />
          <MiniStat
            :label="t(`${KEY}.SLA.APPLIED`)"
            :value="slaMetrics.numberOfConversations"
          />
        </div>
        <router-link
          :to="{ name: 'sla_reports' }"
          class="text-[13px] font-medium text-n-brand hover:underline"
        >
          {{ t(`${KEY}.SLA.VIEW_FULL`) }}
        </router-link>
      </MetricCard>
    </div>

    <div class="grid grid-cols-1 gap-5 lg:grid-cols-2">
      <SummaryTableCard
        :title="t(`${KEY}.BY_INBOX.TITLE`)"
        :description="t(`${KEY}.BY_INBOX.DESCRIPTION`)"
        :name-label="t(`${KEY}.DIMENSION.INBOX`)"
        icon="i-lucide-inbox"
        :rows="inboxSummary"
        :is-loading="isLoading && !inboxSummary.length"
        @download="download('inbox')"
      />
      <SummaryTableCard
        :title="t(`${KEY}.BY_AGENT.TITLE`)"
        :description="t(`${KEY}.BY_AGENT.DESCRIPTION`)"
        :name-label="t(`${KEY}.DIMENSION.ASSIGNEE`)"
        icon="i-lucide-users"
        :rows="agentSummary"
        :is-loading="isLoading && !agentSummary.length"
        @download="download('agent')"
      />
    </div>

    <StatusBreakdownCard
      :rows="statusData?.breakdown ?? []"
      :totals="statusData?.totals"
      :dimension="dimension"
      :is-loading="isLoading && !statusData"
      @update:dimension="dimension = $event"
    />

    <ConversationHeatmapContainer />
    <ResolutionHeatmapContainer />
  </template>
</template>
