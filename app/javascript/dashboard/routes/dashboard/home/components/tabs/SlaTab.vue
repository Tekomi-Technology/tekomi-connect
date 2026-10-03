<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from '../cards/DashboardCard.vue';
import MiniStat from '../cards/MiniStat.vue';
import TrendChart from '../cards/TrendChart.vue';
import SlaGaugeCard from '../cards/SlaGaugeCard.vue';
import ActivityFeedCard from '../cards/ActivityFeedCard.vue';
import { useChartTheme } from '../../composables/useChartTheme';
import { formatNumber } from '../../helpers';

const props = defineProps({
  data: { type: Object, required: true },
  groupBy: { type: String, required: true },
});

const { t } = useI18n();
const { colors } = useChartTheme();

const sla = computed(() => props.data.sla);

const series = computed(() => [
  {
    name: t('HOME.DASHBOARD.SLA.HIT'),
    data: sla.value.timeseries.map(({ timestamp, hit }) => ({
      timestamp,
      value: hit,
    })),
  },
  {
    name: t('HOME.DASHBOARD.SLA.MISSED_SERIES'),
    data: sla.value.timeseries.map(({ timestamp, missed }) => ({
      timestamp,
      value: missed,
    })),
  },
]);

const missedEvents = computed(() =>
  props.data.activity.filter(event => event.type === 'sla_missed')
);
</script>

<template>
  <SlaGaugeCard v-if="!sla" :sla="null" />
  <div v-else class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <div class="grid grid-cols-2 gap-3 lg:col-span-12 md:grid-cols-4">
      <MiniStat
        :label="t('HOME.DASHBOARD.SLA.HIT_LABEL')"
        :value="sla.hit_rate ?? '—'"
        :unit="sla.hit_rate == null ? '' : '%'"
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.SLA.MISSED_SERIES')"
        :value="formatNumber(sla.missed)"
        tone="ruby"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.SLA.TRACKING')"
        :value="formatNumber(sla.active)"
        tone="amber"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.SLA.TOTAL')"
        :value="formatNumber(sla.total)"
      />
    </div>
    <SlaGaugeCard :sla="sla" class="lg:col-span-4" />
    <DashboardCard
      :title="t('HOME.DASHBOARD.SLA.CHART_TITLE')"
      :subtitle="t('HOME.DASHBOARD.SLA.CHART_SUBTITLE')"
      icon="i-lucide-chart-column-stacked"
      class="lg:col-span-8"
    >
      <TrendChart
        type="bar"
        stacked
        :series="series"
        :group-by="groupBy"
        :colors="[colors.brand, colors.ruby]"
        :height="280"
      />
    </DashboardCard>
    <ActivityFeedCard
      :events="missedEvents"
      :title="t('HOME.DASHBOARD.SLA.MISSED_TITLE')"
      :subtitle="t('HOME.DASHBOARD.SLA.MISSED_SUBTITLE')"
      class="lg:col-span-12"
    />
  </div>
</template>
