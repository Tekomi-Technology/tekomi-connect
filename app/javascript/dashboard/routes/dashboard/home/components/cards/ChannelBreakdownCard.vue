<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardCard from './DashboardCard.vue';
import {
  SERIES_DOT_CLASSES,
  channelLabelKey,
  formatNumber,
  percent,
} from '../../helpers';

const props = defineProps({
  channels: { type: Array, default: () => [] },
});

const { t } = useI18n();

const total = computed(() =>
  props.channels.reduce((sum, channel) => sum + channel.total, 0)
);

const rows = computed(() =>
  props.channels.map((channel, index) => ({
    ...channel,
    label: t(channelLabelKey(channel.channel_type)),
    share: percent(channel.total, total.value),
    dot: SERIES_DOT_CLASSES[index % SERIES_DOT_CLASSES.length],
  }))
);

// Bars grow from zero once mounted so each tab switch redraws them.
const isDrawn = ref(false);
onMounted(() =>
  requestAnimationFrame(() => {
    isDrawn.value = true;
  })
);
</script>

<template>
  <DashboardCard
    :title="t('HOME.DASHBOARD.CHANNELS_CARD.TITLE')"
    :subtitle="t('HOME.DASHBOARD.CHANNELS_CARD.SUBTITLE')"
    icon="i-lucide-radio-tower"
  >
    <template #action>
      <span
        class="px-2 py-0.5 rounded-full bg-n-brand/10 text-n-brand text-[11px] font-semibold whitespace-nowrap"
      >
        {{
          t('HOME.DASHBOARD.CHANNELS_CARD.TOTAL', {
            count: formatNumber(total),
          })
        }}
      </span>
    </template>
    <p v-if="!rows.length" class="py-8 text-sm text-center text-n-slate-11">
      {{ t('HOME.DASHBOARD.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-4">
      <li
        v-for="row in rows"
        :key="row.channel_type"
        class="flex flex-col gap-1.5"
      >
        <div class="flex items-center justify-between gap-2 text-[13px]">
          <span class="flex items-center gap-2 min-w-0 text-n-slate-12">
            <span class="rounded-full size-2 shrink-0" :class="row.dot" />
            <span class="truncate">{{ row.label }}</span>
          </span>
          <span class="font-semibold text-n-slate-12 shrink-0">
            {{ formatNumber(row.total) }}
            <span class="font-normal text-n-slate-11">
              {{
                t('HOME.DASHBOARD.COMMON.PERCENT_PAREN', { value: row.share })
              }}
            </span>
          </span>
        </div>
        <div class="h-2 overflow-hidden rounded-full bg-n-alpha-2">
          <div
            class="h-full rounded-full transition-all duration-700 ease-out motion-reduce:transition-none"
            :class="row.dot"
            :style="{ width: `${isDrawn ? row.share : 0}%` }"
          />
        </div>
      </li>
    </ul>
  </DashboardCard>
</template>
