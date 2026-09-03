<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import ConversationApi from 'dashboard/api/inbox/conversation';
import SLAReportsAPI from 'dashboard/api/slaReports';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const agentStatus = useMapGetter('agents/getAgentStatus');

const startOfWeek = () => {
  const date = new Date();
  date.setDate(date.getDate() - 6);
  date.setHours(0, 0, 0, 0);
  return Math.floor(date.getTime() / 1000);
};

// Each figure is fetched independently (Promise.allSettled, not Promise.all)
// so one endpoint failing degrades only its own card instead of blanking all
// four. A settled-but-failed (or intentionally skipped, see below) figure
// resolves to `null`; the template renders '—' only for that field.
const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const agentId = currentUser.value?.id;
  const from = startOfWeek();
  const to = Math.floor(Date.now() / 1000);

  const [openResult, pendingResult, slaResult] = await Promise.allSettled([
    ConversationApi.meta({ status: 'open', assigneeType: 'me' }),
    ConversationApi.meta({ status: 'pending', assigneeType: 'me' }),
    // Never send the SLA request unfiltered — without a real agent id it
    // would silently return account-wide misses mislabelled as "mine". If
    // the id hasn't hydrated yet, skip the request and leave the figure
    // null; the `watch` below re-runs `load()` once the id shows up.
    agentId
      ? SLAReportsAPI.getMetrics({ from, to, assigned_agent_id: agentId })
      : Promise.resolve(null),
  ]);

  return {
    open:
      openResult.status === 'fulfilled'
        ? openResult.value.data.meta.mine_count
        : null,
    pending:
      pendingResult.status === 'fulfilled'
        ? pendingResult.value.data.meta.mine_count
        : null,
    slaMissed:
      slaResult.status === 'fulfilled' && slaResult.value
        ? slaResult.value.data.number_of_sla_misses
        : null,
    slaTotal:
      slaResult.status === 'fulfilled' && slaResult.value
        ? slaResult.value.data.total_applied_slas
        : null,
  };
});

// `total_applied_slas` is 0 whenever the account has no SLA applied to any
// conversation in the window (in particular, when no SLA policy exists at
// all), so a real 0 misses is indistinguishable from "not configured" — hide
// the card in that case instead of showing a misleading number. `slaTotal`
// is only ever `null` when the request failed or was skipped for a missing
// agent id (not yet confirmed either way), so that case still shows the
// card — degraded to '—' — rather than hiding it.
const showSlaCard = computed(() => {
  if (isLoading.value || hasError.value || !data.value) return true;
  const { slaTotal } = data.value;
  return slaTotal === null || slaTotal > 0;
});

const cards = computed(() => {
  const list = [
    { key: 'OPEN', value: data.value?.open, icon: 'i-lucide-message-circle' },
    { key: 'PENDING', value: data.value?.pending, icon: 'i-lucide-hourglass' },
  ];
  if (showSlaCard.value) {
    list.push({
      key: 'SLA',
      value: data.value?.slaMissed,
      icon: 'i-lucide-triangle-alert',
      alert: true,
    });
  }
  list.push({
    key: 'ONLINE',
    value: agentStatus.value.online,
    icon: 'i-lucide-users',
  });
  return list;
});

// Drive the initial load off the agent id itself (not a bare `onMounted`) so
// a hard refresh landing straight on /home — where `getCurrentUser` may not
// be hydrated yet — doesn't fire the SLA request unfiltered. `immediate`
// covers the common case where the id is already present at mount; the
// watcher fires again once it resolves later, re-running `load()` so the
// SLA figure backfills instead of staying null forever.
watch(
  () => currentUser.value?.id,
  () => {
    load();
  },
  { immediate: true }
);
</script>

<template>
  <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
    <CardLayout v-for="card in cards" :key="card.key" layout="row">
      <div class="flex flex-col gap-2">
        <span class="text-xs text-n-slate-11">{{
          t(`HOME.STATS.${card.key}`)
        }}</span>
        <span
          v-if="isLoading"
          class="w-10 h-7 rounded bg-n-alpha-2 animate-pulse"
        />
        <span
          v-else
          class="text-2xl font-medium"
          :class="
            card.alert && card.value > 0 ? 'text-n-ruby-11' : 'text-n-slate-12'
          "
        >
          {{ hasError || card.value === null ? '—' : card.value }}
        </span>
      </div>
      <span :class="card.icon" class="size-4 text-n-slate-10" />
    </CardLayout>
  </div>
</template>
