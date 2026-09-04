<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import { formatTime } from '@chatwoot/utils';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');

const since = () => {
  const date = new Date();
  date.setDate(date.getDate() - 6);
  date.setHours(0, 0, 0, 0);
  return Math.floor(date.getTime() / 1000);
};
const until = () => Math.floor(Date.now() / 1000);

// The CSAT `/metrics` endpoint returns raw counts (`total_count` and
// `ratings_count` keyed by rating value), not a precomputed score -- there is
// no `satisfaction_score` field. This mirrors the formula the `csat` Vuex
// store already uses elsewhere in the app (ratings of 4 and 5 over the
// total), rounded to a whole percentage for this compact card.
const computeCsatScore = (ratingsCount, totalCount) => {
  if (!totalCount) return 0;
  const satisfied = (ratingsCount?.[4] || 0) + (ratingsCount?.[5] || 0);
  return Math.round((satisfied * 100) / totalCount);
};

// Each figure is fetched independently (Promise.allSettled, not Promise.all)
// so one endpoint failing degrades only its own figure instead of blanking
// the whole card. A settled-but-failed figure resolves to `null`; the
// template renders '—' for it. `hasError` is reserved for an unexpected
// throw in the fetcher itself (e.g. building the request), not for an
// individual endpoint rejecting.
const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const agentId = currentUser.value?.id;
  const from = since();
  const to = until();

  const [summaryResult, seriesResult, csatResult] = await Promise.allSettled([
    ReportsAPI.getSummary(from, to, 'agent', agentId),
    ReportsAPI.getReports({
      metric: 'resolutions_count',
      from,
      to,
      type: 'agent',
      id: agentId,
      groupBy: 'day',
    }),
    CSATReportsAPI.getMetrics({ from, to, user_ids: [agentId] }),
  ]);

  return {
    firstResponseTime:
      summaryResult.status === 'fulfilled' &&
      summaryResult.value.data.avg_first_response_time != null
        ? formatTime(summaryResult.value.data.avg_first_response_time)
        : null,
    // `conversations_count` counts every conversation touched in the window,
    // regardless of status. `resolutions_count` is the metric that actually
    // matches the "Resolved" label -- and it's the same metric plotted in
    // the trend line below, so the headline figure and the chart agree.
    resolved:
      summaryResult.status === 'fulfilled'
        ? summaryResult.value.data.resolutions_count
        : null,
    touched:
      summaryResult.status === 'fulfilled'
        ? summaryResult.value.data.conversations_count
        : null,
    csat:
      csatResult.status === 'fulfilled'
        ? computeCsatScore(
            csatResult.value.data.ratings_count,
            csatResult.value.data.total_count
          )
        : null,
    series:
      seriesResult.status === 'fulfilled'
        ? seriesResult.value.data.map(point => point.value)
        : [],
  };
});

// Resolution rate is derived from two real summary figures: resolved over
// every conversation touched in the window. Null when either side is missing
// or nothing was touched (avoid a 0/0 divide).
const resolutionRate = computed(() => {
  const { resolved, touched } = data.value ?? {};
  if (resolved == null || !touched) return null;
  return Math.round((resolved * 100) / touched);
});

const weekNumber = computed(() => {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 1);
  const days = Math.floor((now - start) / 86400000);
  return Math.ceil((days + start.getDay() + 1) / 7);
});

const points = computed(() => {
  const series = data.value?.series ?? [];
  const max = Math.max(...series, 1);
  return series
    .map(
      (value, index) =>
        `${(index / Math.max(series.length - 1, 1)) * 100},${
          40 - (value / max) * 36
        }`
    )
    .join(' ');
});

// Drive the initial load off the agent id itself (not a bare `onMounted`) so
// a hard refresh landing straight on /home -- where `getCurrentUser` may not
// be hydrated yet -- never fires these agent-scoped requests without an id.
// Every request this card makes is scoped by agent id (summary, the
// resolutions series, and the CSAT metrics), so an unfiltered request here
// wouldn't just miss one figure -- it would silently return account-wide
// numbers displayed as this agent's own performance. `immediate` covers the
// common case where the id is already present at mount; the watcher fires
// again once it resolves later, so the card backfills instead of staying
// blank forever.
watch(
  () => currentUser.value?.id,
  agentId => {
    if (agentId) load();
  },
  { immediate: true }
);
</script>

<template>
  <div
    class="p-5 rounded-2xl bg-white border border-n-weak shadow-sm dark:bg-n-solid-2"
  >
    <div class="flex items-center justify-between w-full">
      <div>
        <h2 class="text-base font-semibold tracking-tight text-n-slate-12">
          {{ t('HOME.WEEK.TITLE') }}
        </h2>
        <p class="text-xs text-n-slate-11">{{ t('HOME.WEEK.SUBTITLE') }}</p>
      </div>
      <span
        class="px-2 py-1 rounded-lg bg-n-alpha-2 text-n-slate-11 text-[11px] font-semibold font-mono"
      >
        {{ t('HOME.WEEK.WEEK_BADGE', { week: weekNumber }) }}
      </span>
    </div>

    <div
      v-if="isLoading"
      class="h-28 mt-4 rounded-xl bg-n-alpha-2 animate-pulse"
    />

    <button
      v-else-if="hasError"
      class="self-start mt-4 text-[13px] text-n-brand hover:underline"
      @click="load"
    >
      {{ t('HOME.RETRY') }}
    </button>

    <!-- Waiting for the agent id to hydrate before the first load fires. -->
    <div
      v-else-if="!data"
      class="h-28 mt-4 rounded-xl bg-n-alpha-2 animate-pulse"
    />

    <template v-else>
      <div class="grid grid-cols-3 gap-2 mt-4 text-center">
        <div class="flex flex-col items-center">
          <div class="relative size-16">
            <svg viewBox="0 0 42 42" class="-rotate-90 size-16">
              <circle
                cx="21"
                cy="21"
                r="15.9"
                fill="none"
                stroke-width="3.5"
                class="stroke-n-alpha-2"
              />
              <circle
                cx="21"
                cy="21"
                r="15.9"
                fill="none"
                stroke-width="3.5"
                stroke="#4F46E5"
                stroke-linecap="round"
                :stroke-dasharray="`${resolutionRate ?? 0} 100`"
              />
            </svg>
            <span
              class="absolute inset-0 flex items-center justify-center text-[13px] font-bold text-n-slate-12"
            >
              {{ resolutionRate !== null ? `${resolutionRate}%` : '—' }}
            </span>
          </div>
          <span class="mt-2 text-xs font-medium text-n-slate-12">
            {{ t('HOME.WEEK.RATE') }}
          </span>
          <span class="flex items-center gap-1 text-[11px] text-n-slate-11">
            <span>{{ data.resolved ?? '—' }}</span>
            <span>/</span>
            <span>{{ data.touched ?? '—' }}</span>
          </span>
        </div>
        <div class="flex flex-col items-center">
          <div class="relative size-16">
            <svg viewBox="0 0 42 42" class="-rotate-90 size-16">
              <circle
                cx="21"
                cy="21"
                r="15.9"
                fill="none"
                stroke-width="3.5"
                class="stroke-n-alpha-2"
              />
              <circle
                cx="21"
                cy="21"
                r="15.9"
                fill="none"
                stroke-width="3.5"
                stroke="#10B981"
                stroke-linecap="round"
                :stroke-dasharray="`${data.csat ?? 0} 100`"
              />
            </svg>
            <span
              class="absolute inset-0 flex items-center justify-center text-[13px] font-bold text-n-slate-12"
            >
              {{ data.csat !== null ? `${data.csat}%` : '—' }}
            </span>
          </div>
          <span class="mt-2 text-xs font-medium text-n-slate-12">
            {{ t('HOME.WEEK.CSAT') }}
          </span>
        </div>
        <div class="flex flex-col items-center justify-start">
          <p
            class="h-16 flex items-center text-xl font-semibold tracking-tight text-n-slate-12"
          >
            {{ data.firstResponseTime ?? '—' }}
          </p>
          <span class="mt-2 text-xs font-medium text-n-slate-12">
            {{ t('HOME.WEEK.FRT') }}
          </span>
        </div>
      </div>

      <svg
        viewBox="0 0 100 40"
        preserveAspectRatio="none"
        class="w-full h-14 mt-3"
      >
        <polyline
          :points="points"
          fill="none"
          stroke="#4F46E5"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </template>
  </div>
</template>
