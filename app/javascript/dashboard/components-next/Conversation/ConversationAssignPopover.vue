<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import wootConstants from 'dashboard/constants/globals';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: { type: Object, required: true },
});

const TABS = ['agents', 'teams', 'ai'];

const { t } = useI18n();
const store = useStore();
const { agentsList } = useAgentsList(false, { includeAgentBots: true });

const teams = useMapGetter('teams/getTeams');
const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const activeTab = ref('agents');
const searchQuery = ref('');

const isTekomiEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.TEKOMI)
);

const assignee = computed(() => props.chat.meta?.assignee);
const assigneeType = computed(() => props.chat.meta?.assignee_type || 'User');
const team = computed(() => props.chat.meta?.team);
const isPending = computed(
  () => props.chat.status === wootConstants.STATUS_TYPE.PENDING
);

const matchesQuery = name =>
  (name || '').toLowerCase().includes(searchQuery.value.trim().toLowerCase());

const isSelectedAssignee = item =>
  assignee.value?.id === item.id &&
  assigneeType.value === (item.assignee_type || 'User');

const agentItems = computed(() =>
  agentsList.value.filter(
    agent => agent.assignee_type !== 'AgentBot' && matchesQuery(agent.name)
  )
);

const botItems = computed(() =>
  agentsList.value.filter(
    agent => agent.assignee_type === 'AgentBot' && matchesQuery(agent.name)
  )
);

const teamItems = computed(() =>
  teams.value.filter(item => matchesQuery(item.name))
);

const tabCounts = computed(() => ({
  agents: agentItems.value.length,
  teams: teamItems.value.length,
  ai: botItems.value.length + (isTekomiEnabled.value ? 1 : 0),
}));

const assignAgent = item => {
  const nextAssignee = isSelectedAssignee(item) ? null : item;
  const nextType = nextAssignee ? item.assignee_type || 'User' : null;
  store.dispatch('setCurrentChatAssignee', {
    conversationId: props.chat.id,
    assignee: nextAssignee,
    assigneeType: nextType,
  });
  store
    .dispatch('assignAgent', {
      conversationId: props.chat.id,
      agentId: nextAssignee ? nextAssignee.id : null,
      assigneeType: nextType,
    })
    .then(() => useAlert(t('CONVERSATION.CHANGE_AGENT')));
};

const assignTeam = item => {
  const nextTeam = team.value?.id === item.id ? null : item;
  store.dispatch('setCurrentChatTeam', {
    team: nextTeam,
    conversationId: props.chat.id,
  });
  store
    .dispatch('assignTeam', {
      conversationId: props.chat.id,
      teamId: nextTeam ? nextTeam.id : 0,
    })
    .then(() => useAlert(t('CONVERSATION.CHANGE_TEAM')));
};

const handOverToTekomi = () => {
  store
    .dispatch('toggleStatus', {
      conversationId: props.chat.id,
      status: wootConstants.STATUS_TYPE.PENDING,
    })
    .then(() => useAlert(t('CONVERSATION.CHANGE_STATUS')));
};

const select = (action, item, hide) => {
  action(item);
  hide();
};

const rowClass = isActive =>
  isActive
    ? 'bg-n-brand/10 text-n-brand font-semibold'
    : 'text-n-slate-12 hover:bg-n-alpha-2';
</script>

<template>
  <Popover align="end" :close-on-scroll="false" @hide="searchQuery = ''">
    <template #default="{ isOpen }">
      <Button
        :label="t('CONVERSATION.HEADER.ASSIGN.TRIGGER')"
        icon="i-lucide-user-round-plus"
        size="sm"
        color="slate"
        variant="outline"
        :class="{ 'bg-n-alpha-2': isOpen }"
      />
    </template>
    <template #content="{ hide }">
      <div class="flex flex-col w-72 max-h-[28rem] p-1.5">
        <div
          class="flex items-center gap-1 p-0.5 mb-1.5 rounded-lg bg-n-alpha-1"
        >
          <button
            v-for="tab in TABS"
            :key="tab"
            type="button"
            class="flex items-center justify-center flex-1 h-7 gap-1 text-xs rounded-md"
            :class="
              activeTab === tab
                ? 'bg-n-solid-1 text-n-slate-12 font-semibold shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTab = tab"
          >
            {{ t(`CONVERSATION.HEADER.ASSIGN.TABS.${tab.toUpperCase()}`) }}
            <span class="text-[11px] text-n-slate-10">
              {{ tabCounts[tab] }}
            </span>
          </button>
        </div>
        <input
          v-model="searchQuery"
          type="search"
          class="reset-base w-full h-8 px-2.5 mb-1 text-sm rounded-lg bg-n-alpha-1 outline outline-1 outline-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-n-brand"
          :placeholder="t('CONVERSATION.HEADER.ASSIGN.SEARCH')"
        />
        <div class="flex flex-col flex-1 min-h-0 gap-0.5 overflow-y-auto">
          <template v-if="activeTab === 'agents'">
            <button
              v-for="item in agentItems"
              :key="item.id"
              type="button"
              class="flex items-center w-full gap-2.5 px-2 py-1.5 text-sm rounded-lg text-start"
              :class="rowClass(isSelectedAssignee(item))"
              @click="select(assignAgent, item, hide)"
            >
              <Avatar
                :name="item.name"
                :src="item.thumbnail"
                :size="24"
                :status="item.availability_status"
                rounded-full
              />
              <span class="flex-1 min-w-0 truncate">{{ item.name }}</span>
              <span
                v-if="isSelectedAssignee(item)"
                class="i-lucide-check size-4 shrink-0"
              />
            </button>
          </template>

          <template v-else-if="activeTab === 'teams'">
            <button
              v-for="item in teamItems"
              :key="item.id"
              type="button"
              class="flex items-center w-full gap-2.5 px-2 py-1.5 text-sm rounded-lg text-start"
              :class="rowClass(team?.id === item.id)"
              @click="select(assignTeam, item, hide)"
            >
              <span
                class="grid rounded-full size-6 shrink-0 place-items-center bg-n-alpha-2"
              >
                <span class="i-lucide-users size-3.5 text-n-slate-11" />
              </span>
              <span class="flex-1 min-w-0 truncate">{{ item.name }}</span>
              <span
                v-if="team?.id === item.id"
                class="i-lucide-check size-4 shrink-0"
              />
            </button>
          </template>

          <template v-else>
            <button
              v-if="isTekomiEnabled"
              type="button"
              class="flex items-center w-full gap-2.5 px-2 py-1.5 text-sm rounded-lg text-start"
              :class="rowClass(isPending)"
              :disabled="isPending"
              @click="select(handOverToTekomi, null, hide)"
            >
              <span
                class="grid rounded-full size-6 shrink-0 place-items-center bg-n-violet-3"
              >
                <span class="i-lucide-sparkles size-3.5 text-n-violet-11" />
              </span>
              <span class="flex flex-col flex-1 min-w-0">
                <span class="truncate">
                  {{ t('CONVERSATION.HEADER.ASSIGN.TEKOMI_AI') }}
                </span>
                <span class="text-[11px] font-normal text-n-slate-11">
                  {{ t('CONVERSATION.HEADER.ASSIGN.TEKOMI_AI_HINT') }}
                </span>
              </span>
              <span v-if="isPending" class="i-lucide-check size-4 shrink-0" />
            </button>
            <button
              v-for="item in botItems"
              :key="`bot-${item.id}`"
              type="button"
              class="flex items-center w-full gap-2.5 px-2 py-1.5 text-sm rounded-lg text-start"
              :class="rowClass(isSelectedAssignee(item))"
              @click="select(assignAgent, item, hide)"
            >
              <Avatar
                :name="item.name"
                :src="item.thumbnail"
                :size="24"
                rounded-full
                hide-offline-status
              />
              <span class="flex-1 min-w-0 truncate">{{ item.name }}</span>
              <span
                v-if="isSelectedAssignee(item)"
                class="i-lucide-check size-4 shrink-0"
              />
            </button>
          </template>

          <p
            v-if="!tabCounts[activeTab]"
            class="px-2 py-6 mb-0 text-xs text-center text-n-slate-11"
          >
            {{ t('CONVERSATION.HEADER.ASSIGN.EMPTY') }}
          </p>
        </div>
      </div>
    </template>
  </Popover>
</template>
