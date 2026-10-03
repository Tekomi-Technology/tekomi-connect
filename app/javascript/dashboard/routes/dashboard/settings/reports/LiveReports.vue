<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { formatTime } from '@chatwoot/utils';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import TrendChart from 'dashboard/routes/dashboard/home/components/cards/TrendChart.vue';
import RadialChart from 'dashboard/routes/dashboard/home/components/cards/RadialChart.vue';
import MiniStat from 'dashboard/routes/dashboard/home/components/cards/MiniStat.vue';
import { useChartTheme } from 'dashboard/routes/dashboard/home/composables/useChartTheme';
import ReportHeader from './components/ReportHeader.vue';
import MetricCard from './components/overview/MetricCard.vue';
import SummaryTableCard from './components/overview/SummaryTableCard.vue';
import StatusBreakdownCard from './components/overview/StatusBreakdownCard.vue';
import ConversationHeatmapContainer from './components/heatmaps/ConversationHeatmapContainer.vue';
import ResolutionHeatmapContainer from './components/heatmaps/ResolutionHeatmapContainer.vue';
import { CONVERSATION_STATUSES } from './constants';
import { useReportsOverview } from './composables/useReportsOverview';

const PERIODS = ['week', 'month', 'quarter'];
const KEY = 'OVERVIEW_REPORTS.SUMMARY';

const { t } = useI18n();
const store = useStore();
const { colors } = useChartTheme();

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

const statusColors = computed(() => [
  colors.value.brand,
  colors.value.palette[1],
  colors.value.amber,
  colors.value.palette[4],
]);

const timelineSeries = computed(() =>
  CONVERSATION_STATUSES.map(status => ({
    name: t(`${KEY}.STATUS.${status.toUpperCase()}`),
    data: (statusData.value?.timeline ?? []).map(point => ({
      timestamp: point.timestamp,
      value: point[status],
    })),
  }))
);

const hasTimeline = computed(() => Boolean(statusData.value?.timeline?.length));

const resolutionRate = computed(() => {
  const { conversations_count: total, resolutions_count: resolved } =
    summary.value;
  return total ? Math.round((resolved / total) * 100) : 0;
});

const slaHitRate = computed(() =>
  Number.parseFloat(slaMetrics.value.hitRate) || 0
);

const kpis = computed(() => [
  {
    key: 'conversations',
    value: summary.value.conversations_count,
  },
  {
    key: 'resolved',
    value: summary.value.resolutions_count,
    hint: t(`${KEY}.KPI.RESOLVED_HINT`, { rate: resolutionRate.value }),
  },
  {
    key: 'first_response',
    value: formatTime(summary.value.avg_first_response_time || 0),
  },
  {
    key: 'resolution_time',
    value: formatTime(summary.value.avg_resolution_time || 0),
  },
  {
    key: 'sla',
    value: slaMetrics.value.hitRate,
    hint: t(`${KEY}.KPI.SLA_HINT`, {
      count: slaMetrics.value.numberOfSLAMisses,
    }),
  },
]);

const download = (action, type) => {
  const { since, until } = range.value;
  store.dispatch(action, {
    from: since,
    to: until,
    fileName: generateFileName({ type, to: until }),
  });
};

onMounted(load);
</script>

<template>
  <ReportHeader
    is-live
    :header-title="$t('OVERVIEW_REPORTS.HEADER')"
    :header-description="t(`${KEY}.SUBTITLE`)"
  >
    <Button
      :label="t(`${KEY}.EXPORT`)"
      icon="i-lucide-download"
      size="sm"
      @click="download('downloadConversationsSummaryReports')"
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
    <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
      <div
        v-for="kpi in kpis"
        :key="kpi.key"
        class="flex flex-col gap-1 p-4 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
      >
        <span class="text-xs text-n-slate-11">
          {{ t(`${KEY}.KPI.${kpi.key.toUpperCase()}`) }}
        </span>
        <span
          class="text-2xl font-semibold tracking-tight text-n-slate-12 tabular-nums"
        >
          {{ kpi.value }}
        </span>
        <span v-if="kpi.hint" class="text-[11px] text-n-slate-11">
          {{ kpi.hint }}
        </span>
      </div>
    </div>

    <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
      <MetricCard
        class="lg:col-span-8"
        :header="t(`${KEY}.TIMELINE.TITLE`)"
        :description="t(`${KEY}.TIMELINE.DESCRIPTION`)"
        icon="i-lucide-bar-chart-3"
        :show-live-badge="false"
        :is-loading="isLoading && !statusData"
        :loading-message="t(`${KEY}.LOADING`)"
        body-class="w-full min-w-0"
      >
        <div class="w-full min-w-0">
          <div class="flex flex-wrap items-center gap-4 mb-2">
            <span
              v-for="(status, index) in CONVERSATION_STATUSES"
              :key="status"
              class="flex items-center gap-1.5 text-[11px] text-n-slate-11"
            >
              <span
                class="rounded-sm size-2"
                :style="{ backgroundColor: statusColors[index] }"
              />
              {{ t(`${KEY}.STATUS.${status.toUpperCase()}`) }}
            </span>
          </div>
          <TrendChart
            v-if="hasTimeline"
            stacked
            type="bar"
            :series="timelineSeries"
            :colors="statusColors"
            :group-by="range.groupBy"
            :height="300"
          />
          <p v-else class="py-16 text-sm text-center text-n-slate-11">
            {{ t(`${KEY}.EMPTY`) }}
          </p>
        </div>
      </MetricCard>

      <MetricCard
        class="lg:col-span-4"
        :header="t(`${KEY}.SLA.TITLE`)"
        :description="t(`${KEY}.SLA.DESCRIPTION`, {
          count: slaMetrics.numberOfConversations,
        })"
        icon="i-lucide-timer"
        :show-live-badge="false"
        body-class="flex flex-col w-full min-w-0 gap-4"
      >
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
        @download="download('downloadInboxReports')"
      />
      <SummaryTableCard
        :title="t(`${KEY}.BY_AGENT.TITLE`)"
        :description="t(`${KEY}.BY_AGENT.DESCRIPTION`)"
        :name-label="t(`${KEY}.DIMENSION.ASSIGNEE`)"
        icon="i-lucide-users"
        :rows="agentSummary"
        :is-loading="isLoading && !agentSummary.length"
        @download="download('downloadAgentReports')"
      />
    </div>

    <StatusBreakdownCard
      :rows="statusData?.breakdown ?? []"
      :totals="statusData?.totals"
      :dimension="dimension"
      :is-loading="isLoading && !statusData"
      @update:dimension="dimension = $event"
      @download="download('downloadConversationsSummaryReports')"
    />

    <ConversationHeatmapContainer />
    <ResolutionHeatmapContainer />
  </template>
</template>
