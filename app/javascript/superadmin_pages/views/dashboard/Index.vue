<script setup>
import { computed, onMounted, ref } from 'vue';
import { format, formatDistanceToNow, parseISO } from 'date-fns';
import BarChart from 'shared/components/charts/BarChart.vue';

const props = defineProps({
  componentData: {
    type: Object,
    required: true,
  },
});

const labels = computed(() => props.componentData.labels);

const stats = ref(null);
const failed = ref(false);
const refreshing = ref(false);
const activeChannel = ref('all');

const loading = computed(() => !stats.value && !failed.value);

const numberFormatter = new Intl.NumberFormat();

const interpolate = (template, values) =>
  Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`%{${key}}`, value),
    template || ''
  );

const formatNumber = value =>
  Number.isFinite(value) ? numberFormatter.format(value) : '0';

const loadStats = async () => {
  refreshing.value = true;
  try {
    const response = await fetch(window.location.pathname, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    stats.value = await response.json();
    failed.value = false;
  } catch {
    failed.value = true;
  } finally {
    refreshing.value = false;
  }
};

onMounted(loadStats);

const updatedAt = computed(() => {
  if (!stats.value?.generatedAt) return '';
  return interpolate(labels.value.updated_at, {
    time: formatDistanceToNow(parseISO(stats.value.generatedAt), {
      addSuffix: true,
    }),
  });
});

const metricCards = computed(() => {
  const metrics = stats.value?.metrics;
  if (!metrics) return [];

  return [
    {
      key: 'accounts',
      label: labels.value.accounts,
      value: metrics.accounts.value,
      delta: metrics.accounts.delta,
      detail: interpolate(labels.value.accounts_detail, {
        count: formatNumber(metrics.accounts.detail.active),
      }),
    },
    {
      key: 'users',
      label: labels.value.users,
      value: metrics.users.value,
      delta: metrics.users.delta,
      detail: interpolate(labels.value.users_detail, {
        count: formatNumber(metrics.users.detail.recent),
      }),
    },
    {
      key: 'inboxes',
      label: labels.value.inboxes,
      value: metrics.inboxes.value,
      delta: metrics.inboxes.delta,
      detail: interpolate(labels.value.inboxes_detail, {
        count: formatNumber(metrics.inboxes.detail.channels),
      }),
    },
    {
      key: 'conversations',
      label: labels.value.conversations,
      value: metrics.conversations.value,
      delta: metrics.conversations.delta,
      detail: interpolate(labels.value.conversations_detail, {
        count: formatNumber(metrics.conversations.detail.peak),
      }),
    },
  ];
});

const channelTabs = computed(() =>
  (stats.value?.chart?.series || []).map(({ id, label }) => ({ id, label }))
);

const chartData = computed(() => {
  const chart = stats.value?.chart;
  if (!chart?.series?.length) return { categories: [], series: [] };

  const series =
    chart.series.find(item => item.id === activeChannel.value) ||
    chart.series[0];

  return {
    categories: chart.categories.map(day => format(parseISO(day), 'dd-MMM')),
    series: [
      {
        id: series.id,
        label: series.label,
        color: '#1f93ff',
        data: series.data,
      },
    ],
  };
});

const channels = computed(() => stats.value?.channels || []);

const systemTiles = computed(() => {
  const system = stats.value?.system;
  if (!system) return [];

  const { sidekiq, redis } = system;

  return [
    {
      key: 'processes',
      label: labels.value.sidekiq_processes,
      value: formatNumber(sidekiq.processes),
      tone: sidekiq.processes > 0 ? 'ok' : 'bad',
    },
    {
      key: 'busy',
      label: labels.value.sidekiq_busy,
      value: formatNumber(sidekiq.busy),
      tone: 'neutral',
    },
    {
      key: 'enqueued',
      label: labels.value.sidekiq_enqueued,
      value: formatNumber(sidekiq.enqueued),
      tone: sidekiq.enqueued > 0 ? 'warn' : 'ok',
    },
    {
      key: 'latency',
      label: labels.value.sidekiq_latency,
      value: interpolate(labels.value.seconds, { count: sidekiq.latency }),
      tone: sidekiq.latency > 60 ? 'warn' : 'ok',
    },
    {
      key: 'postgres',
      label: labels.value.postgres,
      value: system.postgres ? labels.value.up : labels.value.down,
      tone: system.postgres ? 'ok' : 'bad',
    },
    {
      key: 'redis',
      label: labels.value.redis,
      value: redis.alive ? redis.version || labels.value.up : labels.value.down,
      tone: redis.alive ? 'ok' : 'bad',
    },
    {
      key: 'migrations',
      label: labels.value.migrations,
      value: system.migrationsPending
        ? labels.value.migrations_pending
        : labels.value.migrations_done,
      tone: system.migrationsPending ? 'warn' : 'ok',
    },
    {
      key: 'push',
      label: labels.value.push_subscriptions,
      value: formatNumber(system.push.subscriptions),
      tone: 'neutral',
    },
  ];
});

const toneClass = tone =>
  ({
    ok: 'text-green-700',
    warn: 'text-yellow-700',
    bad: 'text-red-700',
    neutral: 'text-slate-800',
  })[tone];

const deltaClass = delta => {
  if (delta === null || delta === undefined) return 'bg-slate-50 text-slate-600';
  if (delta > 0) return 'bg-green-100 text-green-700';
  if (delta < 0) return 'bg-red-100 text-red-700';
  return 'bg-slate-50 text-slate-600';
};

const deltaText = delta => {
  if (delta === null || delta === undefined) return labels.value.no_baseline;
  return `${delta > 0 ? '+' : ''}${delta}%`;
};

const activity = computed(() =>
  (stats.value?.activity || []).map(entry => ({
    ...entry,
    actionLabel:
      labels.value[`activity_action_${entry.action}`] || entry.action,
    relativeTime: formatDistanceToNow(parseISO(entry.at), { addSuffix: true }),
  }))
);
</script>

<template>
  <div class="w-full h-full bg-slate-25">
    <header class="main-content__header" role="banner">
      <div class="flex flex-wrap gap-4 justify-between items-start w-full">
        <div class="flex flex-col gap-1 min-w-0">
          <div class="flex gap-3 items-center">
            <h1 id="page-title" class="main-content__page-title">
              {{ labels.title }}
            </h1>
            <span
              class="inline-flex gap-1.5 items-center px-2 py-0.5 text-xs font-medium rounded-full bg-green-100 text-green-700"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-green-700" />
              {{ labels.live }}
            </span>
          </div>
          <p class="max-w-prose text-sm text-slate-600">
            {{ labels.subtitle }}
          </p>
        </div>

        <div class="flex gap-3 items-center">
          <span
            class="px-3 py-1.5 text-xs font-medium rounded-lg border border-slate-75 text-slate-600"
          >
            {{ labels.window }}
          </span>
          <button
            type="button"
            class="px-3 py-1.5 text-xs font-semibold text-white rounded-lg bg-woot-500 hover:bg-woot-600 disabled:opacity-60"
            :disabled="refreshing"
            @click="loadStats"
          >
            {{ labels.refresh }}
          </button>
        </div>
      </div>
    </header>

    <section class="flex flex-col gap-6 px-8 pt-6 pb-12">
      <p
        v-if="failed"
        class="px-4 py-3 text-sm rounded-lg bg-red-100 text-red-700"
      >
        {{ labels.failed_to_load }}
      </p>

      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div
          v-for="index in loading ? 4 : 0"
          :key="`metric-skeleton-${index}`"
          class="h-32 rounded-xl animate-pulse bg-woot-100"
        />
        <div
          v-for="card in metricCards"
          :key="card.key"
          class="flex flex-col gap-2 p-5 bg-white rounded-xl border border-slate-75"
        >
          <span class="text-sm text-slate-600">{{ card.label }}</span>
          <div class="flex flex-wrap gap-2 items-baseline">
            <span class="text-3xl font-bold tabular-nums text-slate-800">
              {{ formatNumber(card.value) }}
            </span>
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full"
              :class="deltaClass(card.delta)"
            >
              {{ deltaText(card.delta) }}
            </span>
          </div>
          <span class="text-xs text-slate-600">{{ card.detail }}</span>
        </div>
      </div>

      <div
        v-if="loading"
        class="h-96 rounded-xl animate-pulse bg-woot-100"
      />
      <div
        v-else-if="!failed"
        class="flex flex-col gap-5 p-6 bg-white rounded-xl border border-slate-75"
      >
        <div class="flex flex-wrap gap-4 justify-between items-start">
          <div class="flex flex-col gap-1 min-w-0">
            <h2 class="text-base font-semibold text-slate-800">
              {{ labels.chart_title }}
            </h2>
            <p class="text-sm text-slate-600">{{ labels.chart_subtitle }}</p>
          </div>
          <div class="flex flex-wrap gap-1 p-1 rounded-lg bg-slate-25">
            <button
              v-for="tab in channelTabs"
              :key="tab.id"
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md"
              :class="
                activeChannel === tab.id
                  ? 'bg-white text-woot-600 shadow-sm'
                  : 'text-slate-600'
              "
              @click="activeChannel = tab.id"
            >
              {{ tab.label }}
            </button>
          </div>
        </div>

        <BarChart
          :data="chartData"
          :height="420"
          timeseries
          :aria-label="labels.chart_aria_label"
        />
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <div
          class="flex flex-col gap-5 p-6 bg-white rounded-xl border border-slate-75"
        >
          <div class="flex flex-col gap-1">
            <h2 class="text-base font-semibold text-slate-800">
              {{ labels.channels_title }}
            </h2>
            <p class="text-sm text-slate-600">{{ labels.channels_subtitle }}</p>
          </div>

          <p v-if="!loading && !channels.length" class="text-sm text-slate-600">
            {{ labels.channels_empty }}
          </p>

          <div v-else class="flex flex-col gap-4">
            <div
              v-for="index in loading ? 3 : 0"
              :key="`channel-skeleton-${index}`"
              class="h-10 rounded animate-pulse bg-woot-100"
            />
            <div
              v-for="channel in channels"
              :key="channel.id"
              class="flex flex-col gap-2"
            >
              <div class="flex gap-3 justify-between items-baseline">
                <span class="text-sm font-medium truncate text-slate-800">
                  {{ channel.label }}
                </span>
                <span class="flex gap-2 items-baseline shrink-0">
                  <span class="text-sm tabular-nums text-slate-600">
                    {{ formatNumber(channel.conversations) }}
                  </span>
                  <span
                    class="px-2 py-0.5 text-xs font-medium rounded-full bg-woot-50 text-woot-600"
                  >
                    {{ channel.share }}%
                  </span>
                </span>
              </div>
              <div class="overflow-hidden w-full h-2 rounded-full bg-slate-50">
                <div
                  class="h-full rounded-full bg-woot-600"
                  :style="{ width: `${channel.share}%` }"
                />
              </div>
            </div>
          </div>
        </div>

        <div
          class="flex flex-col gap-5 p-6 bg-white rounded-xl border border-slate-75"
        >
          <div class="flex flex-wrap gap-3 justify-between items-baseline">
            <h2 class="text-base font-semibold text-slate-800">
              {{ labels.system_title }}
            </h2>
            <span class="text-xs text-slate-600">{{ updatedAt }}</span>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div
              v-for="index in loading ? 8 : 0"
              :key="`tile-skeleton-${index}`"
              class="h-16 rounded-lg animate-pulse bg-woot-100"
            />
            <div
              v-for="tile in systemTiles"
              :key="tile.key"
              class="flex flex-col gap-1 p-3 rounded-lg bg-slate-25"
            >
              <span class="text-xs truncate text-slate-600">
                {{ tile.label }}
              </span>
              <span
                class="text-sm font-semibold tabular-nums"
                :class="toneClass(tile.tone)"
              >
                {{ tile.value }}
              </span>
            </div>
          </div>

          <div class="flex flex-col gap-3">
            <div class="flex flex-col gap-1">
              <h3 class="text-sm font-semibold text-slate-800">
                {{ labels.activity_title }}
              </h3>
              <p class="text-xs text-slate-600">
                {{ labels.activity_subtitle }}
              </p>
            </div>

            <p
              v-if="!loading && !activity.length"
              class="text-sm text-slate-600"
            >
              {{ labels.activity_empty }}
            </p>

            <ul v-else class="flex flex-col gap-2">
              <li
                v-for="entry in activity"
                :key="entry.id"
                class="flex gap-3 justify-between items-baseline text-sm"
              >
                <span class="flex gap-2 items-baseline min-w-0">
                  <span class="font-medium text-slate-800">
                    {{ entry.actionLabel }}
                  </span>
                  <span class="truncate text-slate-600">
                    {{ entry.type }} · {{ entry.user || labels.activity_system }}
                  </span>
                </span>
                <span class="text-xs shrink-0 text-slate-600">
                  {{ entry.relativeTime }}
                </span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
