<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from '../cards/DashboardCard.vue';
import MiniStat from '../cards/MiniStat.vue';
import TrendChart from '../cards/TrendChart.vue';
import CategoryBarChart from '../cards/CategoryBarChart.vue';
import { formatDuration, formatNumber, percent } from '../../helpers';

const props = defineProps({
  data: { type: Object, required: true },
  groupBy: { type: String, required: true },
});

const { t } = useI18n();

const summary = computed(() => props.data.summary);
const formatSeconds = value => formatDuration(value, t);

const distribution = computed(() => props.data.first_response_distribution);
const bucketKeys = computed(() => Object.keys(distribution.value));
const bucketTotal = computed(() =>
  Object.values(distribution.value).reduce((sum, count) => sum + count, 0)
);

const series = computed(() => [
  {
    name: t('HOME.DASHBOARD.RESPONSE.FIRST'),
    data: props.data.timeseries.avg_first_response_time,
  },
]);
</script>

<template>
  <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <div class="grid grid-cols-2 gap-3 lg:col-span-12 md:grid-cols-4">
      <MiniStat
        :label="t('HOME.DASHBOARD.RESPONSE.FIRST')"
        :value="formatSeconds(summary.avg_first_response_time)"
        :hint="
          t('HOME.DASHBOARD.COMMON.PREVIOUS_VALUE', {
            value: formatSeconds(summary.previous.avg_first_response_time),
          })
        "
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.RESPONSE.REPLY')"
        :value="formatSeconds(summary.reply_time)"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.RESPONSE.WITHIN_HOUR')"
        :value="percent(distribution['0-1h'], bucketTotal)"
        unit="%"
        tone="violet"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.QUEUE.UNATTENDED')"
        :value="formatNumber(data.live.unattended)"
        tone="ruby"
      />
    </div>
    <DashboardCard
      :title="t('HOME.DASHBOARD.RESPONSE.CHART_TITLE')"
      :subtitle="t('HOME.DASHBOARD.RESPONSE.CHART_SUBTITLE')"
      icon="i-lucide-timer"
      class="lg:col-span-8"
    >
      <TrendChart
        type="line"
        :series="series"
        :group-by="groupBy"
        :height="300"
        :format-value="formatSeconds"
      />
    </DashboardCard>
    <DashboardCard
      :title="t('HOME.DASHBOARD.RESPONSE.DISTRIBUTION_TITLE')"
      :subtitle="t('HOME.DASHBOARD.RESPONSE.DISTRIBUTION_SUBTITLE')"
      icon="i-lucide-chart-bar"
      class="lg:col-span-4"
    >
      <CategoryBarChart
        :categories="bucketKeys"
        :values="bucketKeys.map(key => distribution[key])"
        :name="t('HOME.DASHBOARD.RESPONSE.CONVERSATIONS')"
        :height="300"
      />
    </DashboardCard>
  </div>
</template>
