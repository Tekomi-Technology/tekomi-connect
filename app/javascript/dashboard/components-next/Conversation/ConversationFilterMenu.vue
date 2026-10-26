<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import { useConversationFilterCountsStore } from 'dashboard/stores/conversationFilterCounts';

const props = defineProps({
  title: { type: String, required: true },
  isMineView: { type: Boolean, default: false },
});

const QUICK_FILTERS = [
  { key: 'all', icon: 'i-lucide-inbox' },
  { key: 'unread', icon: 'i-lucide-mail', alert: true },
  { key: 'unanswered', icon: 'i-lucide-message-circle', alert: true },
  { key: 'unassigned', icon: 'i-lucide-user-x', hideOnMine: true },
  { key: 'ai', icon: 'i-lucide-bot', hideOnMine: true },
  { key: 'pinned', icon: 'i-lucide-pin' },
  { key: 'direct', icon: 'i-lucide-message-square' },
  { key: 'group', icon: 'i-lucide-users' },
  {
    key: 'mention',
    icon: 'i-lucide-at-sign',
    hideOnMine: true,
    routeNames: ['conversation_mentions', 'conversation_through_mentions'],
  },
  {
    key: 'participating',
    icon: 'i-lucide-user-round-check',
    hideOnMine: true,
    routeNames: [
      'conversation_participating',
      'conversation_through_participating',
    ],
  },
];

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const countsStore = useConversationFilterCountsStore();

const popoverRef = ref(null);
const searchQuery = ref('');

const inboxes = useMapGetter('inboxes/getInboxes');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const teams = useMapGetter('teams/getMyTeams');
const folders = useMapGetter('customViews/getConversationCustomViews');

const accountParams = computed(() => ({
  accountId: route.params.accountId,
}));
const baseRouteName = computed(() =>
  props.isMineView ? 'conversation_mine' : 'home'
);
const filterQuery = computed(() =>
  route.query.filter ? { filter: route.query.filter } : {}
);
const listQuery = computed(() =>
  Object.fromEntries(
    ['filter', 'inbox_id', 'label']
      .filter(key => route.query[key])
      .map(key => [key, route.query[key]])
  )
);

const formatCount = count => {
  if (!count) return '';
  return count > 99 ? '99+' : String(count);
};

const matchesSearch = name =>
  name.toLowerCase().includes(searchQuery.value.trim().toLowerCase());

const isOnRoutes = names => names.includes(route.name);

const isQuickFilterActive = item => {
  if (item.routeNames) return isOnRoutes(item.routeNames);
  if (item.key === 'all') {
    return (
      !route.query.filter &&
      isOnRoutes([
        'home',
        'inbox_conversation',
        'conversation_mine',
        'conversation_through_mine',
      ])
    );
  }
  return route.query.filter === item.key;
};

const quickFilters = computed(() =>
  QUICK_FILTERS.filter(item => !(props.isMineView && item.hideOnMine)).map(
    item => {
      const count = countsStore.filters[item.key] || 0;
      return {
        ...item,
        label: t(`CHAT_LIST.FILTER_MENU.QUICK.${item.key.toUpperCase()}`),
        count: formatCount(count),
        isAlert: item.alert && count > 0,
        isActive: isQuickFilterActive(item),
      };
    }
  )
);

const selectedInboxId = computed(
  () => route.params.inbox_id || route.query.inbox_id
);
const selectedLabel = computed(() => route.params.label || route.query.label);

const channelItems = computed(() =>
  inboxes.value
    .filter(inbox => matchesSearch(inbox.name))
    .map(inbox => ({
      inbox,
      isActive: String(selectedInboxId.value) === String(inbox.id),
    }))
);

const labelItems = computed(() =>
  labels.value
    .filter(label => matchesSearch(label.title))
    .map(label => ({
      ...label,
      count: formatCount(countsStore.labels[label.title]),
      isActive: selectedLabel.value === label.title,
    }))
);

const folderItems = computed(() =>
  props.isMineView
    ? []
    : folders.value
        .filter(folder => matchesSearch(folder.name))
        .map(folder => ({
          ...folder,
          count: formatCount(countsStore.folders[folder.id]),
          isActive:
            isOnRoutes([
              'folder_conversations',
              'conversations_through_folders',
            ]) && String(route.params.id) === String(folder.id),
        }))
);

const teamItems = computed(() =>
  props.isMineView
    ? []
    : teams.value
        .filter(team => matchesSearch(team.name))
        .map(team => ({
          ...team,
          count: formatCount(countsStore.teams[team.id]),
          isActive: String(route.params.teamId) === String(team.id),
        }))
);

const navigate = location => {
  popoverRef.value?.hide();
  router.push(location);
};

const selectQuickFilter = item => {
  if (item.routeNames) {
    navigate({ name: item.routeNames[0], params: accountParams.value });
    return;
  }
  if (item.key === 'all') {
    navigate({ name: baseRouteName.value, params: accountParams.value });
    return;
  }
  navigate({ query: { ...listQuery.value, filter: item.key } });
};

const selectChannel = inboxId => {
  if (props.isMineView) {
    const { inbox_id: _removed, ...rest } = listQuery.value;
    navigate({ query: inboxId ? { ...rest, inbox_id: inboxId } : rest });
    return;
  }
  navigate(
    inboxId
      ? {
          name: 'inbox_dashboard',
          params: { ...accountParams.value, inbox_id: inboxId },
          query: filterQuery.value,
        }
      : { name: 'home', params: accountParams.value, query: filterQuery.value }
  );
};

const selectLabel = title => {
  if (props.isMineView) {
    navigate({ query: { ...listQuery.value, label: title } });
    return;
  }
  navigate({
    name: 'label_conversations',
    params: { ...accountParams.value, label: title },
    query: filterQuery.value,
  });
};

const selectTeam = teamId =>
  navigate({
    name: 'team_conversations',
    params: { ...accountParams.value, teamId },
    query: filterQuery.value,
  });

const selectFolder = folderId =>
  navigate({
    name: 'folder_conversations',
    params: { ...accountParams.value, id: folderId },
  });

const itemClass = isActive =>
  isActive
    ? 'bg-n-brand/10 text-n-brand font-medium'
    : 'text-n-slate-12 hover:bg-n-alpha-2';

const countClass = (isActive, isAlert) => {
  if (isActive) return 'bg-n-brand/15 text-n-brand';
  if (isAlert) return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-alpha-2 text-n-slate-11';
};
</script>

<template>
  <Popover
    ref="popoverRef"
    align="start"
    :close-on-scroll="false"
    @hide="searchQuery = ''"
  >
    <template #default="{ isOpen }">
      <button
        type="button"
        class="flex items-center min-w-0 gap-1 px-1.5 py-1 -ms-1.5 rounded-lg hover:bg-n-alpha-2"
        :class="{ 'bg-n-alpha-2': isOpen }"
        :title="t('CHAT_LIST.FILTER_MENU.TRIGGER')"
      >
        <h1 class="text-base font-semibold truncate text-n-slate-12">
          {{ title }}
        </h1>
        <span class="i-lucide-chevron-down size-4 shrink-0 text-n-slate-10" />
      </button>
    </template>
    <template #content>
      <div class="flex flex-col w-72 max-h-[34rem] p-1.5 overflow-y-auto">
        <input
          v-model="searchQuery"
          type="search"
          class="reset-base w-full h-8 px-2.5 mb-1 text-sm rounded-lg bg-n-alpha-1 outline outline-1 outline-n-weak text-n-slate-12 placeholder:text-n-slate-10 focus:outline-n-brand"
          :placeholder="t('CHAT_LIST.FILTER_MENU.SEARCH')"
        />

        <template v-if="!searchQuery">
          <p
            class="px-2.5 pt-2 pb-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
          >
            {{ t('CHAT_LIST.FILTER_MENU.FILTERS') }}
          </p>
          <button
            v-for="item in quickFilters"
            :key="item.key"
            type="button"
            class="flex items-center justify-between w-full h-8 gap-2 px-2.5 text-sm rounded-lg text-start"
            :class="itemClass(item.isActive)"
            @click="selectQuickFilter(item)"
          >
            <span class="flex items-center min-w-0 gap-2.5">
              <span class="size-4 shrink-0" :class="item.icon" />
              <span class="truncate">{{ item.label }}</span>
            </span>
            <span
              v-if="item.count"
              class="inline-grid h-5 min-w-5 px-1.5 place-items-center rounded-full text-xxs font-semibold"
              :class="countClass(item.isActive, item.isAlert)"
            >
              {{ item.count }}
            </span>
          </button>
        </template>

        <template v-if="channelItems.length">
          <p
            class="px-2.5 pt-3 pb-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
          >
            {{ t('CHAT_LIST.FILTER_MENU.CHANNELS') }}
          </p>
          <button
            v-if="!searchQuery"
            type="button"
            class="flex items-center w-full h-8 gap-2.5 px-2.5 text-sm rounded-lg text-start"
            :class="itemClass(!selectedInboxId)"
            @click="selectChannel(null)"
          >
            <span class="i-lucide-layers size-4 shrink-0" />
            <span class="truncate">
              {{ t('CHAT_LIST.FILTER_MENU.ALL_CHANNELS') }}
            </span>
          </button>
          <button
            v-for="item in channelItems"
            :key="item.inbox.id"
            type="button"
            class="flex items-center w-full h-8 gap-2.5 px-2.5 text-sm rounded-lg text-start"
            :class="itemClass(item.isActive)"
            @click="selectChannel(item.inbox.id)"
          >
            <ChannelIcon
              :inbox="item.inbox"
              use-brand-icon
              class="size-4 shrink-0"
            />
            <span class="truncate">{{ item.inbox.name }}</span>
          </button>
        </template>

        <template v-if="folderItems.length">
          <p
            class="px-2.5 pt-3 pb-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
          >
            {{ t('CHAT_LIST.FILTER_MENU.FOLDERS') }}
          </p>
          <button
            v-for="folder in folderItems"
            :key="folder.id"
            type="button"
            class="flex items-center justify-between w-full h-8 gap-2 px-2.5 text-sm rounded-lg text-start"
            :class="itemClass(folder.isActive)"
            @click="selectFolder(folder.id)"
          >
            <span class="flex items-center min-w-0 gap-2.5">
              <span class="i-lucide-folder size-4 shrink-0" />
              <span class="truncate">{{ folder.name }}</span>
            </span>
            <span
              v-if="folder.count"
              class="inline-grid h-5 min-w-5 px-1.5 place-items-center rounded-full text-xxs font-semibold"
              :class="countClass(folder.isActive, false)"
            >
              {{ folder.count }}
            </span>
          </button>
        </template>

        <template v-if="teamItems.length">
          <p
            class="px-2.5 pt-3 pb-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
          >
            {{ t('CHAT_LIST.FILTER_MENU.TEAMS') }}
          </p>
          <button
            v-for="team in teamItems"
            :key="team.id"
            type="button"
            class="flex items-center justify-between w-full h-8 gap-2 px-2.5 text-sm rounded-lg text-start"
            :class="itemClass(team.isActive)"
            @click="selectTeam(team.id)"
          >
            <span class="flex items-center min-w-0 gap-2.5">
              <span class="i-lucide-users-round size-4 shrink-0" />
              <span class="truncate">{{ team.name }}</span>
            </span>
            <span
              v-if="team.count"
              class="inline-grid h-5 min-w-5 px-1.5 place-items-center rounded-full text-xxs font-semibold"
              :class="countClass(team.isActive, false)"
            >
              {{ team.count }}
            </span>
          </button>
        </template>

        <template v-if="labelItems.length">
          <p
            class="px-2.5 pt-3 pb-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
          >
            {{ t('CHAT_LIST.FILTER_MENU.LABELS') }}
          </p>
          <button
            v-for="label in labelItems"
            :key="label.id"
            type="button"
            class="flex items-center justify-between w-full h-8 gap-2 px-2.5 text-sm rounded-lg text-start"
            :class="itemClass(label.isActive)"
            @click="selectLabel(label.title)"
          >
            <span class="flex items-center min-w-0 gap-2.5">
              <span
                class="rounded-full size-2 shrink-0"
                :style="{ backgroundColor: label.color }"
              />
              <span class="truncate">{{ label.title }}</span>
            </span>
            <span
              v-if="label.count"
              class="inline-grid h-5 min-w-5 px-1.5 place-items-center rounded-full text-xxs font-semibold"
              :class="countClass(label.isActive, false)"
            >
              {{ label.count }}
            </span>
          </button>
        </template>
      </div>
    </template>
  </Popover>
</template>
