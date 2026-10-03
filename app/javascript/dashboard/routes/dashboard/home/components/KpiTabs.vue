<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  channelLabelKey,
  deltaPercent,
  formatNumber,
  percent,
  splitDuration,
} from '../helpers';

const props = defineProps({
  data: { type: Object, default: null },
  direction: { type: String, default: 'forward' },
});

const activeTab = defineModel({ type: String, required: true });

const { t } = useI18n();

const TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  warn: 'text-n-amber-11',
  neutral: 'text-n-slate-11',
};

// Positive deltas are good unless `lowerIsBetter`.
const deltaHint = (current, previous, { lowerIsBetter = false } = {}) => {
  const delta = deltaPercent(current, previous);
  if (delta === null || delta === 0) {
    return { text: t('HOME.DASHBOARD.DELTA.FLAT'), tone: 'neutral', icon: '' };
  }
  const isUp = delta > 0;
  const isGood = lowerIsBetter ? !isUp : isUp;
  let key = isUp ? 'UP' : 'DOWN';
  if (lowerIsBetter) key = isUp ? 'SLOWER' : 'FASTER';
  return {
    text: t(`HOME.DASHBOARD.DELTA.${key}`, { value: Math.abs(delta) }),
    tone: isGood ? 'good' : 'bad',
    icon: isUp ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down',
  };
};

const tiles = computed(() => {
  const data = props.data;
  const summary = data?.summary ?? {};
  const previous = summary.previous ?? {};
  const csat = data?.csat ?? {};
  const sla = data?.sla;
  const live = data?.live ?? {};
  const topChannel = data?.channels?.[0];
  const channelTotal = (data?.channels ?? []).reduce(
    (sum, channel) => sum + channel.total,
    0
  );
  const needsAttention = (live.unattended ?? 0) + (live.starred_waiting ?? 0);
  const response = splitDuration(summary.avg_first_response_time);
  const fiveStar = percent(csat.distribution?.[5] ?? 0, csat.total);

  return [
    {
      key: 'overview',
      icon: 'i-lucide-layout-dashboard',
      value: t('HOME.DASHBOARD.TABS.OVERVIEW_VALUE'),
      hint: needsAttention
        ? {
            text: t('HOME.DASHBOARD.HINT.NEEDS_ATTENTION', {
              count: needsAttention,
            }),
            tone: 'warn',
            icon: 'i-lucide-bell-ring',
          }
        : {
            text: t('HOME.DASHBOARD.HINT.HEALTHY'),
            tone: 'good',
            icon: 'i-lucide-activity',
          },
    },
    {
      key: 'conversations',
      icon: 'i-lucide-message-square-plus',
      value: formatNumber(summary.conversations_count),
      hint: deltaHint(
        summary.conversations_count,
        previous.conversations_count
      ),
    },
    {
      key: 'resolved',
      icon: 'i-lucide-circle-check-big',
      value: formatNumber(summary.resolutions_count),
      hint: {
        text: t('HOME.DASHBOARD.HINT.COMPLETION', {
          value: Math.min(
            100,
            percent(summary.resolutions_count, summary.conversations_count)
          ),
        }),
        tone: 'good',
        icon: '',
      },
    },
    {
      key: 'response',
      icon: 'i-lucide-timer',
      value: response.value,
      unit: response.unit && t(`HOME.DASHBOARD.UNITS.${response.unit}`),
      hint: deltaHint(
        summary.avg_first_response_time,
        previous.avg_first_response_time,
        { lowerIsBetter: true }
      ),
    },
    {
      key: 'csat',
      icon: 'i-lucide-smile',
      value: csat.average ?? '—',
      unit: csat.average == null ? '' : '/5',
      hint: {
        text: t('HOME.DASHBOARD.HINT.FIVE_STAR', { value: fiveStar }),
        tone: 'neutral',
        icon: 'i-lucide-star',
      },
    },
    {
      key: 'sla',
      icon: 'i-lucide-shield-check',
      value: sla?.hit_rate ?? '—',
      unit: sla?.hit_rate == null ? '' : '%',
      hint: sla?.missed
        ? {
            text: t('HOME.DASHBOARD.HINT.SLA_MISSED', { count: sla.missed }),
            tone: 'bad',
            icon: 'i-lucide-siren',
          }
        : {
            text: t('HOME.DASHBOARD.HINT.SLA_CLEAN'),
            tone: 'good',
            icon: '',
          },
    },
    {
      key: 'channels',
      icon: 'i-lucide-radio-tower',
      value: topChannel ? t(channelLabelKey(topChannel.channel_type)) : '—',
      isText: true,
      hint: {
        text: t('HOME.DASHBOARD.HINT.SHARE', {
          value: percent(topChannel?.total ?? 0, channelTotal),
        }),
        tone: 'neutral',
        icon: '',
      },
    },
  ];
});

const tileClass = key =>
  activeTab.value === key
    ? 'bg-gradient-to-br from-n-brand/10 to-transparent ring-2 ring-n-brand/60 border-transparent shadow-[0_14px_32px_-14px_rgb(var(--teal-9)/0.7)] [transform:perspective(700px)_translateY(-4px)]'
    : 'bg-white dark:bg-n-solid-2 border-n-weak shadow-sm hover:shadow-md hover:[transform:perspective(700px)_rotateX(6deg)_translateY(-2px)]';
</script>

<template>
  <div
    role="tablist"
    class="grid grid-cols-2 gap-3 sm:grid-cols-4 xl:grid-cols-7"
  >
    <button
      v-for="tile in tiles"
      :key="tile.key"
      type="button"
      role="tab"
      :aria-selected="activeTab === tile.key"
      class="relative flex flex-col gap-2 p-4 overflow-hidden text-left border rounded-2xl transition-all duration-500 ease-out motion-reduce:transition-none"
      :class="tileClass(tile.key)"
      @click="activeTab = tile.key"
    >
      <span
        class="absolute inset-x-0 top-0 h-1 transition-transform duration-500 ease-out bg-n-brand"
        :class="[
          activeTab === tile.key ? 'scale-x-100' : 'scale-x-0',
          direction === 'forward' ? 'origin-left' : 'origin-right',
        ]"
      />
      <span class="flex items-start justify-between gap-2">
        <span
          class="text-[11px] font-semibold uppercase tracking-wide"
          :class="activeTab === tile.key ? 'text-n-brand' : 'text-n-slate-11'"
        >
          {{ t(`HOME.DASHBOARD.TABS.${tile.key.toUpperCase()}`) }}
        </span>
        <span
          class="size-4 shrink-0 transition-colors duration-300"
          :class="[
            tile.icon,
            activeTab === tile.key ? 'text-n-brand' : 'text-n-slate-10',
          ]"
        />
      </span>
      <span class="flex items-baseline gap-1 min-w-0">
        <span
          class="font-semibold tracking-tight text-n-slate-12 truncate"
          :class="
            tile.isText || tile.key === 'overview' ? 'text-xl' : 'text-3xl'
          "
        >
          {{ tile.value }}
        </span>
        <span v-if="tile.unit" class="text-sm font-medium text-n-slate-11">
          {{ tile.unit }}
        </span>
      </span>
      <span
        class="flex items-center gap-1 text-xs font-medium"
        :class="TONES[tile.hint.tone]"
      >
        <span
          v-if="tile.hint.icon"
          class="size-3 shrink-0"
          :class="tile.hint.icon"
        />
        <span class="line-clamp-2">{{ tile.hint.text }}</span>
      </span>
    </button>
  </div>
</template>
