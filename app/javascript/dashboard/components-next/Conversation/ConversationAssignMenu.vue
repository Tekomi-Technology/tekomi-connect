<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { vOnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const { agentsList } = useAgentsList(false, { includeAgentBots: true });
const currentUser = useMapGetter('getCurrentUser');
const teams = useMapGetter('teams/getTeams');

const isOpen = ref(false);

const assignee = computed(() => props.chat.meta?.assignee);
const assigneeType = computed(() => props.chat.meta?.assignee_type || 'User');
const team = computed(() => props.chat.meta?.team);

const isSelectedAgent = agent =>
  assignee.value?.id === agent.id &&
  assigneeType.value === (agent.assignee_type || 'User');

const toAgentItem = agent => ({
  label:
    agent.id === currentUser.value.id && agent.assignee_type !== 'AgentBot'
      ? t('CONVERSATION.HEADER.ASSIGN_MENU.ME', { name: agent.name })
      : agent.name,
  value: `${agent.assignee_type || 'User'}-${agent.id}`,
  action: 'agent',
  agent,
  thumbnail: { name: agent.name, src: agent.thumbnail },
  isSelected: isSelectedAgent(agent),
});

const menuSections = computed(() => {
  const users = agentsList.value.filter(a => a.assignee_type !== 'AgentBot');
  const bots = agentsList.value.filter(a => a.assignee_type === 'AgentBot');
  return [
    {
      title: t('CONVERSATION.HEADER.ASSIGN_MENU.AGENTS'),
      items: users.map(toAgentItem),
    },
    ...(bots.length
      ? [
          {
            title: t('CONVERSATION.HEADER.ASSIGN_MENU.AI'),
            items: bots.map(toAgentItem),
          },
        ]
      : []),
    ...(teams.value.length
      ? [
          {
            title: t('CONVERSATION.HEADER.ASSIGN_MENU.TEAMS'),
            items: teams.value.map(item => ({
              label: item.name,
              value: `Team-${item.id}`,
              action: 'team',
              team: item,
              icon: 'i-lucide-users',
              isSelected: team.value?.id === item.id,
            })),
          },
        ]
      : []),
  ];
});

const assignAgent = async agent => {
  const nextAgent = isSelectedAgent(agent) ? null : agent;
  await store.dispatch('assignAgent', {
    conversationId: props.chat.id,
    agentId: nextAgent?.id ?? null,
    assigneeType: nextAgent ? nextAgent.assignee_type || 'User' : null,
  });
  useAlert(t('CONVERSATION.CHANGE_AGENT'));
};

const assignTeam = async item => {
  await store.dispatch('assignTeam', {
    conversationId: props.chat.id,
    teamId: team.value?.id === item.id ? 0 : item.id,
  });
  useAlert(t('CONVERSATION.CHANGE_TEAM'));
};

const buttonLabel = computed(() =>
  assignee.value
    ? t('CONVERSATION.HEADER.REASSIGN')
    : t('CONVERSATION.HEADER.ASSIGN')
);

const onAction = ({ action, agent, team: item }) => {
  isOpen.value = false;
  if (action === 'agent') assignAgent(agent);
  else assignTeam(item);
};
</script>

<template>
  <div
    v-on-click-outside="() => (isOpen = false)"
    class="relative flex items-center"
  >
    <Button
      v-tooltip.bottom="compact ? buttonLabel : ''"
      :label="compact ? '' : buttonLabel"
      icon="i-lucide-users"
      slate
      outline
      sm
      class="!text-xs !font-semibold"
      :aria-expanded="isOpen"
      @click="isOpen = !isOpen"
    />
    <DropdownMenu
      v-if="isOpen"
      :menu-sections="menuSections"
      show-search
      class="top-full mt-1 end-0 w-64 max-h-96"
      @action="onAction"
    >
      <template #trailing-icon="{ item }">
        <Icon
          v-if="item.isSelected"
          icon="i-lucide-check"
          class="flex-shrink-0 size-4 ms-auto text-n-teal-11"
        />
      </template>
    </DropdownMenu>
  </div>
</template>
