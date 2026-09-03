<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import { formatTime } from '@chatwoot/utils';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
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
  <CardLayout>
    <h2 class="text-sm font-medium text-n-slate-12">
      {{ t('HOME.WEEK.TITLE') }}
    </h2>

    <div v-if="isLoading" class="h-24 rounded bg-n-alpha-2 animate-pulse" />

    <button
      v-else-if="hasError"
      class="self-start text-xs text-n-brand hover:underline"
      @click="load"
    >
      {{ t('HOME.RETRY') }}
    </button>

    <!-- Waiting for the agent id to hydrate before the first load fires. -->
    <div v-else-if="!data" class="h-24 rounded bg-n-alpha-2 animate-pulse" />

    <template v-else>
      <div class="grid grid-cols-3 gap-2">
        <div>
          <p class="text-xs text-n-slate-11">{{ t('HOME.WEEK.FRT') }}</p>
          <p class="text-lg font-medium text-n-slate-12">
            {{ data.firstResponseTime ?? '—' }}
          </p>
        </div>
        <div>
          <p class="text-xs text-n-slate-11">{{ t('HOME.WEEK.RESOLVED') }}</p>
          <p class="text-lg font-medium text-n-slate-12">
            {{ data.resolved ?? '—' }}
          </p>
        </div>
        <div>
          <p class="text-xs text-n-slate-11">{{ t('HOME.WEEK.CSAT') }}</p>
          <p class="text-lg font-medium text-n-slate-12">
            {{ data.csat !== null ? `${data.csat}%` : '—' }}
          </p>
        </div>
      </div>

      <svg viewBox="0 0 100 40" preserveAspectRatio="none" class="w-full h-16">
        <polyline
          :points="points"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          class="text-n-brand"
        />
      </svg>
    </template>
  </CardLayout>
</template>
