<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { formatTime } from '@chatwoot/utils';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import startOfMonth from 'date-fns/startOfMonth';
import TeamMonitoringAPI from 'dashboard/api/teamMonitoring';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const isLoading = ref(false);
const errorMessage = ref('');
const report = ref({ alerts: {}, teams: [], ungroupedAgents: [] });
const expandedTeamIds = ref([]);
const selectedTeamId = ref(null);
const expandedAgentId = ref(null);
const agentConversations = ref([]);
const isLoadingConversations = ref(false);
const dateRange = ref([startOfMonth(new Date()), new Date()]);
const rangeType = ref(DATE_RANGE_TYPES.MONTH_TO_DATE);

const accountId = computed(() => store.getters.getCurrentAccountId);
const selectedTeam = computed(
  () =>
    report.value.teams.find(team => team.id === selectedTeamId.value) ?? null
);

const fetchReport = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    const { data } = await TeamMonitoringAPI.get({
      since: getUnixStartOfDay(dateRange.value[0]),
      until: getUnixEndOfDay(dateRange.value[1]),
    });
    report.value = {
      alerts: data.alerts ?? {},
      teams: data.teams ?? [],
      ungroupedAgents: data.ungrouped_agents ?? [],
    };
  } catch (error) {
    errorMessage.value = t('TEAM_MONITORING.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const onDateRangeChange = value => {
  const [startDate, endDate, selectedRange] = value;
  dateRange.value = [startDate, endDate];
  rangeType.value = selectedRange || DATE_RANGE_TYPES.CUSTOM_RANGE;
  fetchReport();
};

// Clicking a team scopes the alert cards to it and opens its member list; clicking it again goes back to all teams.
const selectTeam = teamId => {
  if (selectedTeamId.value === teamId) {
    selectedTeamId.value = null;
    expandedTeamIds.value = expandedTeamIds.value.filter(id => id !== teamId);
    return;
  }
  selectedTeamId.value = teamId;
  if (!expandedTeamIds.value.includes(teamId)) {
    expandedTeamIds.value = [...expandedTeamIds.value, teamId];
  }
};

const clearTeamSelection = () => {
  selectedTeamId.value = null;
};

const toggleAgentConversations = async agentId => {
  if (expandedAgentId.value === agentId) {
    expandedAgentId.value = null;
    return;
  }
  expandedAgentId.value = agentId;
  agentConversations.value = [];
  isLoadingConversations.value = true;
  try {
    const { data } = await TeamMonitoringAPI.getAgentConversations(agentId);
    agentConversations.value = data;
  } catch (error) {
    agentConversations.value = [];
  } finally {
    isLoadingConversations.value = false;
  }
};

const openConversation = conversationId => {
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: conversationId },
  });
};

const duration = seconds =>
  seconds || seconds === 0 ? formatTime(Math.round(seconds)) : null;

const metricOrEmpty = value =>
  value === null || value === undefined ? t('TEAM_MONITORING.NO_DATA') : value;

const slaMissRate = row => {
  if (!row.sla_applied_count) return t('TEAM_MONITORING.NO_DATA');
  return `${Math.round((row.sla_missed_count / row.sla_applied_count) * 100)}%`;
};

const hasCsat = row =>
  Boolean(row.csat_responses_count) && row.csat_score !== null;

const csatLabel = row => {
  if (!hasCsat(row)) return t('TEAM_MONITORING.NO_DATA');
  return `${row.csat_score} (${row.csat_responses_count})`;
};

const capacityLabel = agent => {
  if (!agent.capacity_limit) return `${agent.open_conversations}`;
  return `${agent.open_conversations}/${agent.capacity_limit}`;
};

const isOverloaded = agent =>
  Boolean(agent.capacity_limit) &&
  agent.open_conversations >= agent.capacity_limit;

const statusLabel = status =>
  t(`TEAM_MONITORING.STATUS.${String(status || 'offline').toUpperCase()}`);

const statusDotClass = status => {
  if (status === 'online') return 'bg-n-teal-10';
  if (status === 'busy') return 'bg-n-amber-10';
  return 'bg-n-slate-8';
};

const statusTextClass = status => {
  if (status === 'online') return 'text-n-teal-11';
  if (status === 'busy') return 'text-n-amber-11';
  return 'text-n-slate-10';
};

// Real figures stand out; «No data» recedes so the eye lands on what was measured.
const VALUE_CLASS = 'font-medium text-n-slate-12';
const NO_DATA_CLASS = 'text-n-slate-10';

const durationClass = seconds =>
  duration(seconds) === null ? NO_DATA_CLASS : VALUE_CLASS;

const csatClass = row => (hasCsat(row) ? VALUE_CLASS : NO_DATA_CLASS);

const slaClass = row => {
  if (!row.sla_applied_count) return NO_DATA_CLASS;
  return row.sla_missed_count
    ? 'font-medium text-n-ruby-11'
    : 'font-medium text-n-teal-11';
};

const TONES = {
  ok: {
    card: 'border-n-teal-6 bg-n-teal-2',
    icon: 'bg-n-teal-4 text-n-teal-11',
    value: 'text-n-slate-12',
  },
  warn: {
    card: 'border-n-amber-6 bg-n-amber-2',
    icon: 'bg-n-amber-4 text-n-amber-11',
    value: 'text-n-amber-11',
  },
  danger: {
    card: 'border-n-ruby-6 bg-n-ruby-2',
    icon: 'bg-n-ruby-4 text-n-ruby-11',
    value: 'text-n-ruby-11',
  },
};

const countCard = (key, icon, label, count, tone = 'warn') => ({
  key,
  icon,
  label,
  value: count ?? 0,
  tone: count ? tone : 'ok',
});

const waitCard = (label, seconds) => ({
  key: 'wait',
  icon: 'i-lucide-hourglass',
  label,
  value: duration(seconds) ?? '—',
  tone: seconds ? 'warn' : 'ok',
});

const accountCards = alerts => [
  countCard(
    'unassigned',
    'i-lucide-inbox',
    t('TEAM_MONITORING.ALERTS.UNASSIGNED'),
    alerts.unassigned_conversations
  ),
  waitCard(
    t('TEAM_MONITORING.ALERTS.LONGEST_WAIT'),
    alerts.longest_waiting_seconds
  ),
  countCard(
    'supervisor',
    'i-lucide-shield-alert',
    t('TEAM_MONITORING.ALERTS.NO_SUPERVISOR'),
    alerts.teams_without_supervisor,
    'danger'
  ),
  countCard(
    'ungrouped',
    'i-lucide-user-x',
    t('TEAM_MONITORING.ALERTS.UNGROUPED'),
    alerts.ungrouped_agents
  ),
];

const overloadedCard = team => {
  const label = t('TEAM_MONITORING.TEAM_ALERTS.OVERLOADED');
  if (!team.agents.some(agent => agent.capacity_limit)) {
    return {
      key: 'overloaded',
      icon: 'i-lucide-gauge',
      label,
      value: t('TEAM_MONITORING.TEAM_ALERTS.NO_LIMIT'),
      tone: 'ok',
      muted: true,
    };
  }
  return countCard(
    'overloaded',
    'i-lucide-gauge',
    label,
    team.agents.filter(isOverloaded).length
  );
};

const teamCards = team => {
  const alerts = team.alerts ?? {};
  return [
    countCard(
      'unassigned',
      'i-lucide-inbox',
      t('TEAM_MONITORING.TEAM_ALERTS.UNASSIGNED'),
      alerts.unassigned_conversations
    ),
    waitCard(
      t('TEAM_MONITORING.TEAM_ALERTS.LONGEST_WAIT'),
      alerts.longest_waiting_seconds
    ),
    countCard(
      'waiting',
      'i-lucide-message-circle-more',
      t('TEAM_MONITORING.TEAM_ALERTS.WAITING'),
      alerts.waiting_conversations
    ),
    overloadedCard(team),
  ];
};

const alertCards = computed(() =>
  selectedTeam.value
    ? teamCards(selectedTeam.value)
    : accountCards(report.value.alerts)
);

onMounted(fetchReport);
</script>

<template>
  <section
    class="flex flex-col w-full h-full gap-6 px-6 py-6 overflow-y-auto no-scrollbar"
  >
    <header class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex flex-col gap-1">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ $t('TEAM_MONITORING.HEADER') }}
        </h1>
        <p class="max-w-2xl mb-0 text-sm text-n-slate-11">
          {{ $t('TEAM_MONITORING.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <WootDatePicker
          v-model:date-range="dateRange"
          v-model:range-type="rangeType"
          @date-range-changed="onDateRangeChange"
        />
        <Button
          icon="i-lucide-refresh-cw"
          slate
          sm
          :is-loading="isLoading"
          :label="$t('TEAM_MONITORING.REFRESH')"
          @click="fetchReport"
        />
      </div>
    </header>

    <div
      v-if="errorMessage"
      class="px-4 py-3 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
    >
      {{ errorMessage }}
    </div>

    <div class="flex flex-col gap-3">
      <div class="flex flex-wrap items-center gap-2 text-sm">
        <span class="text-n-slate-11">
          {{ $t('TEAM_MONITORING.SCOPE.LABEL') }}
        </span>
        <span
          class="px-2 py-0.5 font-medium rounded-md"
          :class="
            selectedTeam
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-alpha-2 text-n-slate-12'
          "
        >
          {{
            selectedTeam ? selectedTeam.name : $t('TEAM_MONITORING.SCOPE.ALL')
          }}
        </span>
        <Button
          v-if="selectedTeam"
          icon="i-lucide-x"
          slate
          xs
          faded
          :label="$t('TEAM_MONITORING.SCOPE.CLEAR')"
          @click="clearTeamSelection"
        />
        <span v-else class="text-xs text-n-slate-10">
          {{ $t('TEAM_MONITORING.SCOPE.HINT') }}
        </span>
      </div>

      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div
          v-for="card in alertCards"
          :key="card.key"
          class="flex items-start gap-3 p-4 border rounded-xl"
          :class="TONES[card.tone].card"
        >
          <span
            class="flex items-center justify-center rounded-lg size-9 shrink-0"
            :class="TONES[card.tone].icon"
          >
            <Icon :icon="card.icon" class="size-5" />
          </span>
          <div class="flex flex-col min-w-0 gap-1">
            <span class="text-sm text-n-slate-11">{{ card.label }}</span>
            <span
              :class="
                card.muted
                  ? 'text-base text-n-slate-10'
                  : ['text-2xl font-semibold', TONES[card.tone].value]
              "
            >
              {{ card.value }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="flex flex-col gap-3">
      <div
        v-for="team in report.teams"
        :key="team.id"
        class="border rounded-xl"
        :class="
          selectedTeamId === team.id
            ? 'border-n-teal-8 ring-1 ring-n-teal-8'
            : 'border-n-weak'
        "
      >
        <button
          class="flex flex-wrap items-center w-full gap-4 px-4 py-3 text-left rounded-xl"
          :class="
            selectedTeamId === team.id ? 'bg-n-teal-2' : 'hover:bg-n-alpha-1'
          "
          @click="selectTeam(team.id)"
        >
          <Icon
            :icon="
              expandedTeamIds.includes(team.id)
                ? 'i-lucide-chevron-down'
                : 'i-lucide-chevron-right'
            "
            class="size-4 text-n-slate-11"
          />
          <div class="flex flex-col flex-1 min-w-40">
            <span class="font-medium capitalize text-n-slate-12">
              {{ team.name }}
            </span>
            <span v-if="team.supervisor" class="text-sm text-n-slate-11">
              {{
                $t('TEAM_MONITORING.SUPERVISED_BY', {
                  name: team.supervisor.name,
                })
              }}
            </span>
            <span v-else class="text-sm font-medium text-n-ruby-11">
              {{ $t('TEAM_MONITORING.NO_SUPERVISOR') }}
            </span>
          </div>
          <div class="flex flex-wrap gap-6">
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.ONLINE') }}
              </span>
              <span
                class="text-sm"
                :class="
                  team.online_members_count
                    ? 'font-medium text-n-teal-11'
                    : NO_DATA_CLASS
                "
              >
                {{ team.online_members_count }}/{{ team.members_count }}
              </span>
            </div>
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.OPEN') }}
              </span>
              <span class="text-sm" :class="VALUE_CLASS">
                {{ team.open_conversations }}
              </span>
            </div>
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.RESOLVED') }}
              </span>
              <span class="text-sm" :class="VALUE_CLASS">
                {{ team.resolved_conversations_count }}
              </span>
            </div>
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.FIRST_RESPONSE') }}
              </span>
              <span
                class="text-sm"
                :class="durationClass(team.avg_first_response_time)"
              >
                {{ metricOrEmpty(duration(team.avg_first_response_time)) }}
              </span>
            </div>
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.RESOLUTION_TIME') }}
              </span>
              <span
                class="text-sm"
                :class="durationClass(team.avg_resolution_time)"
              >
                {{ metricOrEmpty(duration(team.avg_resolution_time)) }}
              </span>
            </div>
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.CSAT') }}
              </span>
              <span class="text-sm" :class="csatClass(team)">
                {{ csatLabel(team) }}
              </span>
            </div>
            <div class="flex flex-col">
              <span class="text-xs text-n-slate-11">
                {{ $t('TEAM_MONITORING.COLUMNS.SLA_MISSED') }}
              </span>
              <span class="text-sm" :class="slaClass(team)">
                {{ slaMissRate(team) }}
              </span>
            </div>
          </div>
        </button>

        <div
          v-if="expandedTeamIds.includes(team.id)"
          class="border-t border-n-weak"
        >
          <p
            v-if="!team.agents.length"
            class="px-4 py-4 mb-0 text-sm text-n-slate-11"
          >
            {{ $t('TEAM_MONITORING.EMPTY_TEAM') }}
          </p>
          <div v-for="agent in team.agents" :key="agent.id">
            <div
              class="flex flex-wrap items-center gap-4 px-4 py-3 border-b border-n-weak last:border-b-0"
            >
              <span
                class="rounded-full size-2"
                :class="statusDotClass(agent.availability_status)"
              />
              <Avatar
                :name="agent.name || ''"
                :src="agent.thumbnail"
                :size="24"
              />
              <div class="flex flex-col flex-1 min-w-32">
                <span class="text-sm text-n-slate-12">{{ agent.name }}</span>
                <span
                  class="text-xs"
                  :class="statusTextClass(agent.availability_status)"
                >
                  {{ statusLabel(agent.availability_status) }}
                </span>
              </div>
              <div class="flex flex-wrap gap-6">
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.OPEN') }}
                  </span>
                  <span
                    class="text-sm"
                    :class="
                      isOverloaded(agent)
                        ? 'font-medium text-n-ruby-11'
                        : VALUE_CLASS
                    "
                  >
                    {{ capacityLabel(agent) }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.CONTACTS') }}
                  </span>
                  <span class="text-sm" :class="VALUE_CLASS">
                    {{ agent.open_contacts }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.RESOLVED') }}
                  </span>
                  <span class="text-sm" :class="VALUE_CLASS">
                    {{ agent.resolved_conversations_count }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.FIRST_RESPONSE') }}
                  </span>
                  <span
                    class="text-sm"
                    :class="durationClass(agent.avg_first_response_time)"
                  >
                    {{ metricOrEmpty(duration(agent.avg_first_response_time)) }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.RESOLUTION_TIME') }}
                  </span>
                  <span
                    class="text-sm"
                    :class="durationClass(agent.avg_resolution_time)"
                  >
                    {{ metricOrEmpty(duration(agent.avg_resolution_time)) }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.CSAT') }}
                  </span>
                  <span class="text-sm" :class="csatClass(agent)">
                    {{ csatLabel(agent) }}
                  </span>
                </div>
                <div class="flex flex-col">
                  <span class="text-xs text-n-slate-11">
                    {{ $t('TEAM_MONITORING.COLUMNS.SLA_MISSED') }}
                  </span>
                  <span class="text-sm" :class="slaClass(agent)">
                    {{ slaMissRate(agent) }}
                  </span>
                </div>
              </div>
              <Button
                :label="
                  expandedAgentId === agent.id
                    ? $t('TEAM_MONITORING.HIDE_CUSTOMERS')
                    : $t('TEAM_MONITORING.SHOW_CUSTOMERS')
                "
                slate
                sm
                faded
                @click="toggleAgentConversations(agent.id)"
              />
            </div>

            <div
              v-if="expandedAgentId === agent.id"
              class="px-10 py-3 bg-n-alpha-1"
            >
              <p
                v-if="isLoadingConversations"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ $t('TEAM_MONITORING.LOADING') }}
              </p>
              <p
                v-else-if="!agentConversations.length"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ $t('TEAM_MONITORING.NO_CUSTOMERS') }}
              </p>
              <ul v-else class="flex flex-col gap-1 m-0 list-none">
                <li
                  v-for="conversation in agentConversations"
                  :key="conversation.id"
                >
                  <button
                    class="flex w-full gap-3 px-2 py-1 text-sm text-left rounded-md hover:bg-n-alpha-2"
                    @click="openConversation(conversation.id)"
                  >
                    <span class="flex-1 text-n-slate-12">
                      {{
                        conversation.contact_name ||
                        $t('TEAM_MONITORING.UNKNOWN_CONTACT')
                      }}
                    </span>
                    <span class="text-n-slate-11">
                      {{ conversation.inbox_name }}
                    </span>
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <p
        v-if="!isLoading && !report.teams.length"
        class="py-10 mb-0 text-sm text-center text-n-slate-11"
      >
        {{ $t('TEAM_MONITORING.EMPTY') }}
      </p>
    </div>

    <div
      v-if="report.ungroupedAgents.length"
      class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak"
    >
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ $t('TEAM_MONITORING.UNGROUPED_TITLE') }}
      </h2>
      <div class="flex flex-wrap gap-3">
        <span
          v-for="agent in report.ungroupedAgents"
          :key="agent.id"
          class="flex items-center gap-2 px-3 py-1 text-sm rounded-full bg-n-alpha-2 text-n-slate-12"
        >
          <span
            class="rounded-full size-2"
            :class="statusDotClass(agent.availability_status)"
          />
          {{ agent.name }} · {{ agent.open_conversations }}
        </span>
      </div>
    </div>

    <p class="mb-0 text-xs text-n-slate-10">
      {{ $t('TEAM_MONITORING.FOOTNOTE') }}
    </p>
  </section>
</template>
