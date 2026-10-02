<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import VueApexCharts from 'vue3-apexcharts';
import DashboardCard from '../cards/DashboardCard.vue';
import MiniStat from '../cards/MiniStat.vue';
import { useChartTheme } from '../../composables/useChartTheme';
import {
  SERIES_DOT_CLASSES,
  channelLabelKey,
  formatNumber,
  percent,
} from '../../helpers';

const props = defineProps({
  data: { type: Object, required: true },
});

const { t } = useI18n();
const { baseOptions, colors } = useChartTheme();

const total = computed(() =>
  props.data.channels.reduce((sum, channel) => sum + channel.total, 0)
);

const rows = computed(() =>
  props.data.channels.map((channel, index) => ({
    ...channel,
    label: t(channelLabelKey(channel.channel_type)),
    share: percent(channel.total, total.value),
    resolvedRate: percent(channel.resolved, channel.total),
    dot: SERIES_DOT_CLASSES[index % SERIES_DOT_CLASSES.length],
  }))
);

const donutOptions = computed(() => ({
  ...baseOptions.value,
  labels: rows.value.map(row => row.label),
  stroke: { width: 2, colors: ['transparent'] },
  plotOptions: {
    pie: {
      donut: {
        size: '70%',
        labels: {
          show: true,
          value: {
            color: colors.value.strong,
            fontSize: '26px',
            fontWeight: 700,
          },
          total: {
            show: true,
            label: t('HOME.DASHBOARD.CHANNELS_TAB.TOTAL'),
            color: colors.value.text,
            formatter: () => formatNumber(total.value),
          },
        },
      },
    },
  },
}));
</script>

<template>
  <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <div class="grid grid-cols-2 gap-3 lg:col-span-12 md:grid-cols-4">
      <MiniStat
        :label="t('HOME.DASHBOARD.CHANNELS_TAB.ACTIVE')"
        :value="rows.length"
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CHANNELS_TAB.LEADER')"
        :value="rows[0]?.label ?? '—'"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CHANNELS_TAB.TOTAL')"
        :value="formatNumber(total)"
        tone="violet"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CONVERSATIONS.OPEN')"
        :value="formatNumber(data.live.open)"
        tone="amber"
      />
    </div>
    <DashboardCard
      :title="t('HOME.DASHBOARD.CHANNELS_TAB.SHARE_TITLE')"
      :subtitle="t('HOME.DASHBOARD.CHANNELS_TAB.SHARE_SUBTITLE')"
      icon="i-lucide-chart-pie"
      class="lg:col-span-5"
    >
      <p v-if="!rows.length" class="py-8 text-sm text-center text-n-slate-11">
        {{ t('HOME.DASHBOARD.EMPTY') }}
      </p>
      <VueApexCharts
        v-else
        type="donut"
        :height="300"
        :options="donutOptions"
        :series="rows.map(row => row.total)"
      />
    </DashboardCard>
    <DashboardCard
      :title="t('HOME.DASHBOARD.CHANNELS_TAB.TABLE_TITLE')"
      :subtitle="t('HOME.DASHBOARD.CHANNELS_TAB.TABLE_SUBTITLE')"
      icon="i-lucide-table"
      class="lg:col-span-7"
    >
      <div class="overflow-x-auto">
        <table class="w-full text-[13px]">
          <thead>
            <tr
              class="text-[11px] uppercase tracking-wide text-n-slate-11 text-left"
            >
              <th class="py-2 font-semibold">
                {{ t('HOME.DASHBOARD.CHANNELS_TAB.CHANNEL') }}
              </th>
              <th class="py-2 font-semibold text-right">
                {{ t('HOME.DASHBOARD.CHANNELS_TAB.TOTAL') }}
              </th>
              <th class="py-2 font-semibold text-right">
                {{ t('HOME.DASHBOARD.CHANNELS_TAB.OPEN') }}
              </th>
              <th class="py-2 font-semibold text-right">
                {{ t('HOME.DASHBOARD.CHANNELS_TAB.RESOLVED') }}
              </th>
              <th class="py-2 font-semibold text-right">
                {{ t('HOME.DASHBOARD.CHANNELS_TAB.SHARE') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="row in rows" :key="row.channel_type">
              <td class="py-3">
                <span class="flex items-center gap-2 text-n-slate-12">
                  <span class="rounded-full size-2 shrink-0" :class="row.dot" />
                  {{ row.label }}
                </span>
              </td>
              <td class="py-3 font-semibold text-right text-n-slate-12">
                {{ formatNumber(row.total) }}
              </td>
              <td class="py-3 text-right text-n-amber-11">
                {{ formatNumber(row.open) }}
              </td>
              <td class="py-3 text-right text-n-teal-11">
                {{ formatNumber(row.resolved) }}
                <span class="text-n-slate-10">
                  {{
                    t('HOME.DASHBOARD.COMMON.PERCENT_PAREN', {
                      value: row.resolvedRate,
                    })
                  }}
                </span>
              </td>
              <td class="py-3 text-right text-n-slate-11">
                {{ t('HOME.DASHBOARD.COMMON.PERCENT', { value: row.share }) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </DashboardCard>
  </div>
</template>
