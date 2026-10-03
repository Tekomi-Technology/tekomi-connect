<script setup>
import { useI18n } from 'vue-i18n';
import DashboardCard from './DashboardCard.vue';
import RadialChart from './RadialChart.vue';

defineProps({
  sla: { type: Object, default: null },
});

const { t } = useI18n();
</script>

<template>
  <DashboardCard
    :title="t('HOME.DASHBOARD.SLA.TITLE')"
    :subtitle="t('HOME.DASHBOARD.SLA.SUBTITLE')"
    icon="i-lucide-shield-check"
  >
    <p v-if="!sla" class="py-10 text-sm text-center text-n-slate-11">
      {{ t('HOME.DASHBOARD.SLA.UNAVAILABLE') }}
    </p>
    <template v-else>
      <RadialChart
        gauge
        :value="sla.hit_rate"
        :label="t('HOME.DASHBOARD.SLA.HIT_LABEL')"
        :height="200"
      />
      <div
        class="flex items-center justify-center gap-4 py-2 text-xs font-medium border rounded-xl border-n-weak"
      >
        <span class="flex items-center gap-1.5 text-n-ruby-11">
          <span class="rounded-full size-2 bg-n-ruby-9" />
          {{ t('HOME.DASHBOARD.SLA.MISSED', { count: sla.missed }) }}
        </span>
        <span class="w-px h-3 bg-n-weak" />
        <span class="flex items-center gap-1.5 text-n-amber-11">
          <span class="rounded-full size-2 bg-n-amber-9" />
          {{ t('HOME.DASHBOARD.SLA.ACTIVE', { count: sla.active }) }}
        </span>
      </div>
    </template>
  </DashboardCard>
</template>
