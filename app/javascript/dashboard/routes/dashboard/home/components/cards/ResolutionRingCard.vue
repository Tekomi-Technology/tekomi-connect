<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from './DashboardCard.vue';
import RadialChart from './RadialChart.vue';
import MiniStat from './MiniStat.vue';
import { formatNumber, percent } from '../../helpers';

const props = defineProps({
  summary: { type: Object, default: () => ({}) },
  live: { type: Object, default: () => ({}) },
});

const { t } = useI18n();

const rate = computed(() =>
  props.summary.conversations_count
    ? Math.min(
        100,
        percent(
          props.summary.resolutions_count,
          props.summary.conversations_count
        )
      )
    : null
);
</script>

<template>
  <DashboardCard
    :title="t('HOME.DASHBOARD.RESOLUTION.TITLE')"
    :subtitle="t('HOME.DASHBOARD.RESOLUTION.SUBTITLE')"
    icon="i-lucide-loader-circle"
  >
    <RadialChart
      :value="rate"
      :label="t('HOME.DASHBOARD.RESOLUTION.DONE')"
      :height="190"
    />
    <div class="grid grid-cols-2 gap-2">
      <MiniStat
        :label="t('HOME.DASHBOARD.RESOLUTION.OPEN')"
        :value="formatNumber(live.open)"
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.RESOLUTION.PENDING')"
        :value="formatNumber(live.pending)"
        tone="amber"
      />
    </div>
  </DashboardCard>
</template>
