<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { getUserPermissions } from 'dashboard/helper/permissionsHelper';
import { formatTime } from '@chatwoot/utils';
import ConversationApi from 'dashboard/api/inbox/conversation';
import LiveReportsAPI from 'dashboard/api/liveReports';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();
const route = useRoute();
const { accountId } = useAccount();
const currentUser = useMapGetter('getCurrentUser');

// Account-wide figures need report visibility (same gate as the Reports
// routes: `administrator` or `report_manage`). Regular agents fall back to
// their own scope so the cards still show real numbers instead of '—'.
const isPrivileged = computed(() => {
  const permissions = getUserPermissions(
    currentUser.value,
    route.params.accountId ?? accountId.value
  );
  return permissions.some(permission =>
    ['administrator', 'report_manage'].includes(permission)
  );
});

const startOfDay = date => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return Math.floor(d.getTime() / 1000);
};
const nowSec = () => Math.floor(Date.now() / 1000);
const DAY = 86400;

// The CSAT `/metrics` endpoint returns raw counts (`total_count` and
// `ratings_count` keyed by rating value), not a precomputed score -- there is
// no `satisfaction_score` field. This mirrors the formula the `csat` Vuex
// store already uses elsewhere in the app (ratings of 4 and 5 over the
// total), rounded to one decimal for this card.
const computeCsatScore = (ratingsCount, totalCount) => {
  if (!totalCount) return null;
  const satisfied = (ratingsCount?.[4] || 0) + (ratingsCount?.[5] || 0);
  return Math.round((satisfied * 1000) / totalCount) / 10;
};

// Every figure is fetched independently (Promise.allSettled, not Promise.all)
// so one endpoint failing degrades only its own card instead of blanking the
// whole row. A settled-but-failed figure resolves to `null`; the template
// renders '—' and hides that card's pill/sparkline.
const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const agentId = currentUser.value?.id;
  const privileged = isPrivileged.value;
  const type = privileged ? 'account' : 'agent';
  const id = privileged ? undefined : agentId;
  const csatScope = privileged ? {} : { user_ids: [agentId] };

  const today = startOfDay(new Date());
  const now = nowSec();
  const yesterday = today - DAY;
  const weekAgo = startOfDay(new Date(Date.now() - 6 * DAY * 1000));
  const prevWeekAgo = weekAgo - 7 * DAY;

  const [
    liveResult,
    mineResult,
    todayResult,
    yesterdayResult,
    resolvedSeriesResult,
    volumeSeriesResult,
    frtSeriesResult,
    csatResult,
    csatPrevResult,
  ] = await Promise.allSettled([
    // Live queue snapshot is account-wide by nature; only usable when the
    // viewer can see account reports, otherwise fall back to "mine".
    privileged ? LiveReportsAPI.getConversationMetric() : Promise.resolve(null),
    ConversationApi.meta({ status: 'open', assigneeType: 'me' }),
    ReportsAPI.getSummary(today, now, type, id),
    ReportsAPI.getSummary(yesterday, today, type, id),
    ReportsAPI.getReports({
      metric: 'resolutions_count',
      from: weekAgo,
      to: now,
      type,
      id,
      groupBy: 'day',
    }),
    ReportsAPI.getReports({
      metric: 'conversations_count',
      from: weekAgo,
      to: now,
      type,
      id,
      groupBy: 'day',
    }),
    // The average-FRT series may not be supported for every grouping; a
    // rejection just hides this card's sparkline (see `frtSpark`).
    ReportsAPI.getReports({
      metric: 'avg_first_response_time',
      from: weekAgo,
      to: now,
      type,
      id,
      groupBy: 'day',
    }),
    CSATReportsAPI.getMetrics({ from: weekAgo, to: now, ...csatScope }),
    CSATReportsAPI.getMetrics({ from: prevWeekAgo, to: weekAgo, ...csatScope }),
  ]);

  const valueOf = result =>
    result.status === 'fulfilled' && result.value ? result.value : null;
  const seriesOf = result =>
    valueOf(result)?.data?.map(point => point.value ?? 0) ?? [];

  const live = valueOf(liveResult)?.data;
  const mine = valueOf(mineResult)?.data?.meta?.mine_count ?? null;
  const todaySummary = valueOf(todayResult)?.data;
  const yesterdaySummary = valueOf(yesterdayResult)?.data;
  const csat = valueOf(csatResult)?.data;
  const csatPrev = valueOf(csatPrevResult)?.data;

  return {
    open: live?.open ?? mine,
    unattended: live?.unattended ?? null,
    resolvedToday: todaySummary?.resolutions_count ?? null,
    resolvedYesterday: yesterdaySummary?.resolutions_count ?? null,
    frtToday: todaySummary?.avg_first_response_time ?? null,
    frtYesterday: yesterdaySummary?.avg_first_response_time ?? null,
    resolvedSpark: seriesOf(resolvedSeriesResult),
    volumeSpark: seriesOf(volumeSeriesResult),
    frtSpark: seriesOf(frtSeriesResult),
    csat: computeCsatScore(csat?.ratings_count, csat?.total_count),
    csatPrev: computeCsatScore(csatPrev?.ratings_count, csatPrev?.total_count),
    csatTotal: csat?.total_count ?? null,
  };
});

const pctChange = (current, previous) => {
  if (current == null || previous == null || previous === 0) return null;
  return Math.round(((current - previous) * 100) / previous);
};

const sparkPoints = values => {
  if (!values.length) return '';
  const max = Math.max(...values, 1);
  const min = Math.min(...values, 0);
  const range = Math.max(max - min, 1);
  return values
    .map(
      (value, index) =>
        `${(index / Math.max(values.length - 1, 1)) * 80},${
          18 - ((value - min) / range) * 16
        }`
    )
    .join(' ');
};

const openPill = computed(() => {
  const { unattended } = data.value ?? {};
  if (unattended == null) return null;
  if (unattended > 0) {
    return {
      text: t('HOME.STATS.UNATTENDED', { count: unattended }),
      tone: 'text-n-amber-11',
    };
  }
  return { text: t('HOME.STATS.ATTENDED'), tone: 'text-[#10B981]' };
});

const resolvedPill = computed(() => {
  const change = pctChange(
    data.value?.resolvedToday,
    data.value?.resolvedYesterday
  );
  if (change == null) return null;
  return {
    text: `${change >= 0 ? '+' : ''}${change}%`,
    tone: change >= 0 ? 'text-[#10B981]' : 'text-n-ruby-11',
  };
});

const frtPill = computed(() => {
  const { frtToday, frtYesterday } = data.value ?? {};
  if (frtToday == null || frtYesterday == null) return null;
  const delta = Math.round(frtToday - frtYesterday);
  return {
    text: `${delta > 0 ? '+' : ''}${delta}s`,
    tone: delta <= 0 ? 'text-[#10B981]' : 'text-n-ruby-11',
  };
});

const csatPill = computed(() => {
  const { csat, csatPrev } = data.value ?? {};
  if (csat == null || csatPrev == null) return null;
  const delta = Math.round((csat - csatPrev) * 10) / 10;
  return {
    text: `${delta >= 0 ? '+' : ''}${delta}%`,
    tone: delta >= 0 ? 'text-[#4F46E5]' : 'text-n-ruby-11',
  };
});

const cards = computed(() => [
  {
    key: 'OPEN',
    value: data.value?.open,
    display: data.value?.open == null ? '—' : String(data.value.open),
    icon: 'i-lucide-inbox',
    tile: 'bg-[#4F46E5]/10 text-[#4F46E5]',
    pill: openPill.value,
    caption: t('HOME.STATS.LIVE'),
    spark: sparkPoints(data.value?.volumeSpark ?? []),
    sparkTone: 'text-[#3B82F6]',
  },
  {
    key: 'RESOLVED',
    value: data.value?.resolvedToday,
    display:
      data.value?.resolvedToday == null
        ? '—'
        : String(data.value.resolvedToday),
    icon: 'i-lucide-check',
    tile: 'bg-[#10B981]/10 text-[#10B981]',
    pill: resolvedPill.value,
    caption: t('HOME.STATS.VS_YESTERDAY'),
    spark: sparkPoints(data.value?.resolvedSpark ?? []),
    sparkTone: 'text-[#10B981]',
  },
  {
    key: 'RESPONSE',
    value: data.value?.frtToday,
    display:
      data.value?.frtToday == null ? '—' : formatTime(data.value.frtToday),
    icon: 'i-lucide-timer',
    tile: 'bg-[#3B82F6]/10 text-[#3B82F6]',
    pill: frtPill.value,
    caption: t('HOME.STATS.VS_YESTERDAY'),
    spark: sparkPoints(data.value?.frtSpark ?? []),
    sparkTone: 'text-[#10B981]',
  },
  {
    key: 'CSAT',
    value: data.value?.csat,
    display: data.value?.csat == null ? '—' : `${data.value.csat}%`,
    icon: 'i-lucide-star',
    tile: 'bg-[#4F46E5]/10 text-[#4F46E5]',
    pill: csatPill.value,
    caption:
      data.value?.csatTotal == null
        ? ''
        : t('HOME.STATS.RATINGS', { count: data.value.csatTotal }),
    spark: '',
    sparkTone: 'text-[#4F46E5]',
  },
]);

// Drive the initial load off the agent id itself (not a bare `onMounted`) so
// a hard refresh landing straight on /home — where `getCurrentUser` may not
// be hydrated yet — doesn't fire agent-scoped requests without an id.
// `immediate` covers the common case where the id is already present at
// mount; the watcher fires again once it resolves later.
watch(
  () => currentUser.value?.id,
  () => {
    load();
  },
  { immediate: true }
);
</script>

<template>
  <section class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
    <div
      v-for="card in cards"
      :key="card.key"
      class="p-5 rounded-2xl bg-white border border-n-weak shadow-sm hover:shadow-md transition-shadow dark:bg-n-solid-2"
    >
      <div class="flex items-center justify-between">
        <span class="text-[13px] font-medium text-n-slate-11">{{
          t(`HOME.STATS.${card.key}`)
        }}</span>
        <span
          class="flex items-center justify-center rounded-lg size-8"
          :class="card.tile"
        >
          <span :class="card.icon" class="size-5" />
        </span>
      </div>
      <div class="flex items-baseline justify-between mt-1">
        <span
          v-if="isLoading"
          class="w-20 h-9 rounded-lg bg-n-alpha-2 animate-pulse"
        />
        <span
          v-else
          class="text-[28px] leading-9 font-semibold tracking-tight text-n-slate-12"
        >
          {{ hasError ? '—' : card.display }}
        </span>
        <span
          v-if="!isLoading && !hasError && card.pill"
          class="flex items-center gap-1 px-2 py-0.5 rounded-full bg-n-alpha-1 text-xs font-medium"
          :class="card.pill.tone"
        >
          {{ card.pill.text }}
        </span>
      </div>
      <div
        class="mt-3 flex items-center justify-between text-xs text-n-slate-11"
      >
        <span>{{ card.caption }}</span>
        <svg
          v-if="card.spark"
          viewBox="0 0 80 20"
          class="w-20 h-5 stroke-current fill-none stroke-2"
          :class="card.sparkTone"
        >
          <path :d="`M ${card.spark.replaceAll(' ', ' L ')}`" />
        </svg>
      </div>
    </div>
  </section>
</template>
