<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from '../cards/DashboardCard.vue';
import MiniStat from '../cards/MiniStat.vue';
import TrendChart from '../cards/TrendChart.vue';
import ResolutionRingCard from '../cards/ResolutionRingCard.vue';
import { formatDuration, formatNumber, percent } from '../../helpers';

const props = defineProps({
  data: { type: Object, required: true },
  groupBy: { type: String, required: true },
});

const { t } = useI18n();

const summary = computed(() => props.data.summary);
const formatSeconds = value => formatDuration(value, t);

const volumeSeries = computed(() => [
  {
    name: t('HOME.DASHBOARD.TRAFFIC.RESOLVED'),
    data: props.data.timeseries.resolutions_count,
  },
  {
    name: t('HOME.DASHBOARD.TRAFFIC.INCOMING'),
    data: props.data.timeseries.conversations_count,
  },
]);

const durationSeries = computed(() => [
  {
    name: t('HOME.DASHBOARD.RESOLVED.AVG_TIME'),
    data: props.data.timeseries.avg_resolution_time,
  },
]);
</script>

<template>
  <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <div class="grid grid-cols-2 gap-3 lg:col-span-12 md:grid-cols-4">
      <MiniStat
        :label="t('HOME.DASHBOARD.RESOLVED.TOTAL')"
        :value="formatNumber(summary.resolutions_count)"
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.RESOLVED.RATE')"
        :value="
          Math.min(
            100,
            percent(summary.resolutions_count, summary.conversations_count)
          )
        "
        unit="%"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.RESOLVED.AVG_TIME')"
        :value="formatSeconds(summary.avg_resolution_time)"
        :hint="
          t('HOME.DASHBOARD.COMMON.PREVIOUS_VALUE', {
            value: formatSeconds(summary.previous.avg_resolution_time),
          })
        "
        tone="violet"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.RESOLUTION.PENDING')"
        :value="formatNumber(data.live.pending)"
        tone="amber"
      />
    </div>
    <DashboardCard
      :title="t('HOME.DASHBOARD.RESOLVED.CHART_TITLE')"
      :subtitle="t('HOME.DASHBOARD.RESOLVED.CHART_SUBTITLE')"
      icon="i-lucide-chart-spline"
      class="lg:col-span-8"
    >
      <TrendChart :series="volumeSeries" :group-by="groupBy" :height="300" />
    </DashboardCard>
    <ResolutionRingCard
      :summary="summary"
      :live="data.live"
      class="lg:col-span-4"
    />
    <DashboardCard
      :title="t('HOME.DASHBOARD.RESOLVED.DURATION_TITLE')"
      :subtitle="t('HOME.DASHBOARD.RESOLVED.DURATION_SUBTITLE')"
      icon="i-lucide-hourglass"
      class="lg:col-span-12"
    >
      <TrendChart
        type="line"
        :series="durationSeries"
        :group-by="groupBy"
        :height="240"
        :format-value="formatSeconds"
      />
    </DashboardCard>
  </div>
</template>
