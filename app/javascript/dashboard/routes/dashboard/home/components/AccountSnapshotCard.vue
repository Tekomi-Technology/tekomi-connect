<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import LiveReportsAPI from 'dashboard/api/liveReports';
import ReportsAPI from 'dashboard/api/reports';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();
const DAY = 86400;

const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const now = Math.floor(Date.now() / 1000);
  const weekAgo = now - 6 * DAY;

  const [liveResult, seriesResult] = await Promise.allSettled([
    LiveReportsAPI.getConversationMetric(),
    ReportsAPI.getReports({
      metric: 'conversations_count',
      from: weekAgo,
      to: now,
      type: 'account',
      groupBy: 'day',
    }),
  ]);

  const live =
    liveResult.status === 'fulfilled' && liveResult.value
      ? liveResult.value.data
      : null;
  const points =
    seriesResult.status === 'fulfilled' && seriesResult.value
      ? seriesResult.value.data.map(point => ({
          value: point.value ?? 0,
          at: point.timestamp,
        }))
      : [];

  return { live, points };
});

// `open` and `pending` are the only two disjoint buckets in the live payload
// -- `unattended` and `unassigned` are both subsets of `open`, not additional
// slices. Summing all four would double-count, so the total only ever
// combines `open` and `pending`.
const live = computed(() => data.value?.live ?? {});
const bars = computed(() => {
  const points = data.value?.points ?? [];
  const max = Math.max(...points.map(point => point.value), 1);
  return points.slice(-7).map(point => ({
    height: Math.max(Math.round((point.value / max) * 100), 6),
    label: point.at
      ? new Date(point.at * 1000).toLocaleDateString(undefined, {
          weekday: 'narrow',
        })
      : '',
    value: point.value,
  }));
});

onMounted(load);
</script>

<template>
  <div
    class="p-5 rounded-2xl bg-white border border-n-weak shadow-sm dark:bg-n-solid-2"
  >
    <div class="flex items-center justify-between w-full">
      <div>
        <h2 class="text-base font-semibold tracking-tight text-n-slate-12">
          {{ t('HOME.ACCOUNT.TITLE') }}
        </h2>
        <p class="text-xs text-n-slate-11">
          {{ t('HOME.ACCOUNT.SUBTITLE') }}
        </p>
      </div>
      <span
        class="px-2 py-1 text-[11px] font-semibold rounded-lg bg-[#4F46E5]/10 text-[#4F46E5]"
      >
        {{ t('HOME.ACCOUNT.ADMIN') }}
      </span>
    </div>

    <div
      v-if="isLoading"
      class="w-full h-28 mt-4 rounded-xl bg-n-alpha-2 animate-pulse"
    />

    <button
      v-else-if="hasError"
      class="self-start mt-4 text-[13px] text-n-brand hover:underline"
      @click="load"
    >
      {{ t('HOME.RETRY') }}
    </button>

    <div v-else class="mt-4">
      <p class="text-[13px] font-medium text-n-slate-11">
        {{ t('HOME.ACCOUNT.VOLUME') }}
      </p>
      <div class="h-28 flex items-end justify-between gap-2 pt-3">
        <div
          v-for="(bar, index) in bars"
          :key="index"
          class="flex-1 flex flex-col items-center gap-1.5 h-full justify-end min-w-0"
        >
          <div
            class="w-full rounded-t-md"
            :class="
              index === bars.length - 1
                ? 'bg-[#4F46E5]'
                : 'bg-[#4F46E5]/25 hover:bg-[#4F46E5]/50'
            "
            :style="{ height: `${bar.height}%` }"
            :title="String(bar.value)"
          />
          <span
            class="text-[11px]"
            :class="
              index === bars.length - 1
                ? 'font-bold text-[#4F46E5]'
                : 'text-n-slate-11'
            "
          >
            {{ bar.label }}
          </span>
        </div>
      </div>
      <div
        class="mt-4 pt-4 border-t border-n-weak grid grid-cols-2 gap-2 text-[13px]"
      >
        <p class="flex items-center gap-2 text-n-slate-11">
          <span class="rounded-full bg-[#4F46E5] size-2 shrink-0" />
          {{ t('HOME.ACCOUNT.OPEN', { count: live.open ?? 0 }) }}
        </p>
        <p class="flex items-center gap-2 text-n-slate-11">
          <span class="rounded-full bg-[#3B82F6] size-2 shrink-0" />
          {{ t('HOME.ACCOUNT.PENDING', { count: live.pending ?? 0 }) }}
        </p>
        <p class="flex items-center gap-2 text-n-slate-10">
          <span class="rounded-full bg-n-alpha-3 size-2 shrink-0" />
          {{ t('HOME.ACCOUNT.UNATTENDED', { count: live.unattended ?? 0 }) }}
        </p>
        <p class="flex items-center gap-2 text-n-slate-10">
          <span class="rounded-full bg-n-alpha-3 size-2 shrink-0" />
          {{ t('HOME.ACCOUNT.UNASSIGNED', { count: live.unassigned ?? 0 }) }}
        </p>
      </div>
    </div>
  </div>
</template>
