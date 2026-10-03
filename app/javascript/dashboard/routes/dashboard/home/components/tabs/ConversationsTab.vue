<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from '../cards/DashboardCard.vue';
import MiniStat from '../cards/MiniStat.vue';
import TrendChart from '../cards/TrendChart.vue';
import ChannelBreakdownCard from '../cards/ChannelBreakdownCard.vue';
import { deltaPercent, formatNumber } from '../../helpers';

const props = defineProps({
  data: { type: Object, required: true },
  groupBy: { type: String, required: true },
  days: { type: Number, required: true },
});

const { t } = useI18n();

const summary = computed(() => props.data.summary);
const delta = computed(() =>
  deltaPercent(
    summary.value.conversations_count,
    summary.value.previous.conversations_count
  )
);

const series = computed(() => [
  {
    name: t('HOME.DASHBOARD.COMMON.THIS_PERIOD'),
    data: props.data.timeseries.conversations_count,
  },
  {
    name: t('HOME.DASHBOARD.COMMON.PREVIOUS_PERIOD'),
    data: props.data.timeseries.previous_conversations_count,
  },
]);
</script>

<template>
  <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <div class="grid grid-cols-2 gap-3 lg:col-span-12 md:grid-cols-4">
      <MiniStat
        :label="t('HOME.DASHBOARD.CONVERSATIONS.TOTAL')"
        :value="formatNumber(summary.conversations_count)"
        :hint="
          delta === null
            ? ''
            : t('HOME.DASHBOARD.COMMON.VS_PREVIOUS', {
                value: delta > 0 ? `+${delta}` : delta,
              })
        "
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CONVERSATIONS.PER_DAY')"
        :value="formatNumber(Math.round(summary.conversations_count / days))"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CONVERSATIONS.OPEN')"
        :value="formatNumber(data.live.open)"
        tone="amber"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CONVERSATIONS.UNASSIGNED')"
        :value="formatNumber(data.live.unassigned)"
        tone="violet"
      />
    </div>
    <DashboardCard
      :title="t('HOME.DASHBOARD.CONVERSATIONS.CHART_TITLE')"
      :subtitle="t('HOME.DASHBOARD.CONVERSATIONS.CHART_SUBTITLE')"
      icon="i-lucide-chart-column"
      class="lg:col-span-8"
    >
      <TrendChart
        type="bar"
        :series="series"
        :group-by="groupBy"
        :height="320"
      />
    </DashboardCard>
    <ChannelBreakdownCard :channels="data.channels" class="lg:col-span-4" />
  </div>
</template>
