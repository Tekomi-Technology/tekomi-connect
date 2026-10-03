<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatTime } from '@chatwoot/utils';
import Button from 'dashboard/components-next/button/Button.vue';
import TrendChart from 'dashboard/routes/dashboard/home/components/cards/TrendChart.vue';
import CategoryBarChart from 'dashboard/routes/dashboard/home/components/cards/CategoryBarChart.vue';
import { useChartTheme } from 'dashboard/routes/dashboard/home/composables/useChartTheme';
import MetricCard from './MetricCard.vue';
import {
  CONVERSATION_STATUSES,
  OVERVIEW_METRIC_FIELDS,
  OVERVIEW_TIME_METRICS,
  STATUS_BAR_CLASS,
} from '../../constants';

const VIEWS = ['inbox', 'agent', 'status'];
const TOP_ROWS = 10;

const props = defineProps({
  metric: { type: String, required: true },
  inboxRows: { type: Array, default: () => [] },
  agentRows: { type: Array, default: () => [] },
  timeline: { type: Array, default: () => [] },
  groupBy: { type: String, required: true },
  isLoading: { type: Boolean, default: false },
});

defineEmits(['download']);

const view = defineModel('view', { type: String, required: true });

const { t } = useI18n();
const { colors } = useChartTheme();
const key = 'OVERVIEW_REPORTS.SUMMARY';

const statusColors = computed(() => [
  colors.value.brand,
  colors.value.palette[1],
  colors.value.amber,
  colors.value.palette[4],
]);

const statusSeries = computed(() =>
  CONVERSATION_STATUSES.map(status => ({
    name: t(`${key}.STATUS.${status.toUpperCase()}`),
    data: props.timeline.map(point => ({
      timestamp: point.timestamp,
      value: point[status],
    })),
  }))
);

const ranked = computed(() => {
  const field = OVERVIEW_METRIC_FIELDS[props.metric];
  const rows = view.value === 'agent' ? props.agentRows : props.inboxRows;
  return rows
    .filter(row => row[field] > 0)
    .sort((a, b) => b[field] - a[field])
    .slice(0, TOP_ROWS)
    .map(row => ({
      name: row.name || t(`${key}.UNKNOWN`),
      value: row[field],
    }));
});

const formatValue = computed(() =>
  OVERVIEW_TIME_METRICS.includes(props.metric)
    ? value => formatTime(value)
    : value => Math.round(value)
);

const description = computed(() =>
  t(`${key}.CHART.BY_${view.value.toUpperCase()}`, {
    metric: t(`${key}.KPI.${props.metric.toUpperCase()}`),
  })
);
</script>

<template>
  <MetricCard
    :header="t(`${key}.CHART.TITLE`)"
    :description="description"
    icon="i-lucide-chart-bar"
    :show-live-badge="false"
    :is-loading="isLoading"
    :loading-message="t(`${key}.LOADING`)"
    body-class="w-full min-w-0"
  >
    <template #control>
      <div
        role="tablist"
        class="flex items-center gap-1 p-1 border rounded-xl bg-n-alpha-1 border-n-weak"
      >
        <button
          v-for="option in VIEWS"
          :key="option"
          type="button"
          role="tab"
          :aria-selected="view === option"
          class="px-3 py-1 rounded-lg text-[13px] font-medium whitespace-nowrap transition-all duration-200"
          :class="
            view === option
              ? 'bg-white shadow-sm text-n-brand dark:bg-n-solid-3'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="view = option"
        >
          {{ t(`${key}.VIEW.${option.toUpperCase()}`) }}
        </button>
      </div>
      <Button
        v-if="view !== 'status'"
        v-tooltip="t(`${key}.DOWNLOAD`)"
        sm
        slate
        faded
        icon="i-lucide-download"
        class="rounded-md"
        @click="$emit('download', view)"
      />
    </template>

    <template v-if="view === 'status'">
      <div class="flex flex-wrap items-center gap-4 mb-2">
        <span
          v-for="status in CONVERSATION_STATUSES"
          :key="status"
          class="flex items-center gap-1.5 text-[11px] text-n-slate-11"
        >
          <span class="rounded-sm size-2" :class="STATUS_BAR_CLASS[status]" />
          {{ t(`${key}.STATUS.${status.toUpperCase()}`) }}
        </span>
      </div>
      <TrendChart
        v-if="timeline.length"
        stacked
        type="bar"
        :series="statusSeries"
        :colors="statusColors"
        :group-by="groupBy"
        :height="300"
      />
      <p v-else class="py-16 text-sm text-center text-n-slate-11">
        {{ t(`${key}.EMPTY`) }}
      </p>
    </template>
    <template v-else>
      <CategoryBarChart
        v-if="ranked.length"
        :key="`${view}-${metric}`"
        horizontal
        :name="t(`${key}.KPI.${metric.toUpperCase()}`)"
        :categories="ranked.map(row => row.name)"
        :values="ranked.map(row => row.value)"
        :format-value="formatValue"
        :height="Math.max(220, ranked.length * 36 + 60)"
      />
      <p v-else class="py-16 text-sm text-center text-n-slate-11">
        {{ t(`${key}.EMPTY`) }}
      </p>
    </template>
  </MetricCard>
</template>
