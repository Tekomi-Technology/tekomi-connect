<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from './DashboardCard.vue';
import TrendChart from './TrendChart.vue';
import { SERIES_DOT_CLASSES } from '../../helpers';

const props = defineProps({
  timeseries: { type: Object, default: () => ({}) },
  groupBy: { type: String, default: 'day' },
});

const { t } = useI18n();

const series = computed(() => [
  {
    name: t('HOME.DASHBOARD.TRAFFIC.INCOMING'),
    data: props.timeseries.conversations_count ?? [],
  },
  {
    name: t('HOME.DASHBOARD.TRAFFIC.RESOLVED'),
    data: props.timeseries.resolutions_count ?? [],
  },
]);
</script>

<template>
  <DashboardCard
    :title="t('HOME.DASHBOARD.TRAFFIC.TITLE')"
    :subtitle="t('HOME.DASHBOARD.TRAFFIC.SUBTITLE')"
    icon="i-lucide-chart-spline"
  >
    <template #action>
      <div class="flex items-center gap-3 text-xs text-n-slate-11">
        <span
          v-for="(item, index) in series"
          :key="item.name"
          class="flex items-center gap-1.5 whitespace-nowrap"
        >
          <span
            class="rounded-full size-2"
            :class="SERIES_DOT_CLASSES[index]"
          />
          {{ item.name }}
        </span>
      </div>
    </template>
    <TrendChart :series="series" :group-by="groupBy" :height="300" />
  </DashboardCard>
</template>
