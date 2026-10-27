<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { vOnClickOutside } from '@vueuse/components';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationFilterPanel } from 'dashboard/composables/useConversationFilterPanel';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { pickConversationListQuery } from 'dashboard/helper/URLHelper';
import {
  SIDEBAR_SORT_SECTIONS,
  getSidebarSortOptions,
  resolveSidebarSort,
  sortSidebarItems,
} from 'dashboard/helper/sidebarSort';
import Button from 'dashboard/components-next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import SidebarSortMenu from 'dashboard/components-next/sidebar/SidebarSortMenu.vue';

const props = defineProps({
  foldersId: { type: [String, Number], default: 0 },
  overlay: { type: Boolean, default: false },
});

const MAIN_FILTERS = [
  { key: 'all', icon: 'i-lucide-inbox' },
  { key: 'unread', icon: 'i-lucide-mail', isAlert: true },
  { key: 'unattended', icon: 'i-lucide-message-circle', isAlert: true },
  { key: 'unassigned', icon: 'i-lucide-user-x', hideOnMine: true },
  { key: 'pinned', icon: 'i-lucide-pin' },
  { key: 'direct', icon: 'i-lucide-message-square' },
  { key: 'group', icon: 'i-lucide-users' },
];

const RELATED_FILTERS = [
  { key: 'mention', icon: 'i-lucide-at-sign' },
  { key: 'participating', icon: 'i-lucide-user-round-check' },
];

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { closePanel } = useConversationFilterPanel();

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getMyTeams');
const labels = useMapGetter('labels/getLabelsOnSidebar');
const folders = useMapGetter('customViews/getConversationCustomViews');
const getSectionSort = useMapGetter('sidebarSortPreferences/getSectionSort');
const allUnreadCount = useMapGetter(
  'conversationUnreadCounts/getAllUnreadCount'
);
const mentionsUnreadCount = useMapGetter(
  'conversationUnreadCounts/getMentionsUnreadCount'
);
const participatingUnreadCount = useMapGetter(
  'conversationUnreadCounts/getParticipatingUnreadCount'
);
const unattendedUnreadCount = useMapGetter(
  'conversationUnreadCounts/getUnattendedUnreadCount'
);
const quickFilterCounts = useMapGetter(
  'conversationUnreadCounts/getQuickFilterCounts'
);
const getInboxUnreadCount = useMapGetter(
  'conversationUnreadCounts/getInboxUnreadCount'
);
const getLabelUnreadCount = useMapGetter(
  'conversationUnreadCounts/getLabelUnreadCount'
);
const getTeamUnreadCount = useMapGetter(
  'conversationUnreadCounts/getTeamUnreadCount'
);
const getFolderUnreadCount = useMapGetter(
  'conversationUnreadCounts/getFolderUnreadCount'
);

const isMine = computed(() => route.query.scope === 'mine');
const title = computed(() =>
  isMine.value ? t('SIDEBAR.INBOX') : t('CHAT_LIST.FILTER_PANEL.TITLE')
);

const isAccountFeatureEnabled = flag =>
  isFeatureEnabledonAccount.value(accountId.value, flag);
const hasUnreadCounts = computed(() =>
  isAccountFeatureEnabled(FEATURE_FLAGS.CONVERSATION_UNREAD_COUNTS)
);
const hasFilteredUnreadCounts = computed(
  () =>
    hasUnreadCounts.value &&
    isAccountFeatureEnabled(FEATURE_FLAGS.UNREAD_COUNT_FOR_FILTERS)
);

const sortCountsAvailable = section =>
  section === SIDEBAR_SORT_SECTIONS.FOLDERS
    ? hasFilteredUnreadCounts.value
    : hasUnreadCounts.value;
const sortFor = section =>
  resolveSidebarSort(section, getSectionSort.value(section), {
    hasUnreadCounts: sortCountsAvailable(section),
  });
const sortOptionsFor = section =>
  getSidebarSortOptions(section, {
    hasUnreadCounts: sortCountsAvailable(section),
  });
const setSort = (section, sortBy) =>
  store.dispatch('sidebarSortPreferences/setSectionSort', { section, sortBy });

const selection = computed(() => {
  if (props.foldersId) return `folder:${props.foldersId}`;
  const { filter, label, team_id: teamId } = route.query;
  if (filter) return `filter:${filter}`;
  if (label) return `label:${label}`;
  if (teamId) return `team:${teamId}`;
  return 'filter:all';
});

const activeInboxId = computed(() =>
  props.foldersId ? '' : String(route.query.inbox_id || '')
);

const goToList = query =>
  router.push({
    name: 'home',
    params: { accountId: route.params.accountId },
    query,
  });

const scopeQuery = () => ({
  ...(isMine.value && { scope: 'mine' }),
  ...(activeInboxId.value && { inbox_id: activeInboxId.value }),
});

const pickFilter = key =>
  goToList({ ...scopeQuery(), ...(key !== 'all' && { filter: key }) });

const pickInbox = inboxId => {
  const query = props.foldersId ? {} : pickConversationListQuery(route.query);
  delete query.inbox_id;
  if (inboxId) query.inbox_id = String(inboxId);
  goToList(query);
};

const filterCounts = computed(() => {
  const counts = quickFilterCounts.value;
  if (isMine.value) {
    return {
      all: counts.mine_all_count,
      unread: counts.mine_all_count,
      unattended: counts.mine_unattended_count,
      pinned: counts.mine_pinned_count,
      direct: counts.mine_direct_count,
      group: counts.mine_group_count,
      mention: counts.mine_mentions_count,
      participating: counts.mine_participating_count,
    };
  }
  return {
    all: allUnreadCount.value,
    unread: allUnreadCount.value,
    unattended: unattendedUnreadCount.value,
    unassigned: counts.unassigned_count,
    pinned: counts.pinned_count,
    direct: counts.direct_count,
    group: counts.group_count,
    mention: mentionsUnreadCount.value,
    participating: participatingUnreadCount.value,
  };
});

const formatCount = count => (count > 99 ? '99+' : count);

const toFilterItem = ({ key, icon, isAlert }) => ({
  key,
  icon,
  isAlert,
  label:
    key === 'all'
      ? t('CHAT_LIST.FILTER_PANEL.ALL')
      : t(`CHAT_LIST.QUICK_FILTERS.${key.toUpperCase()}`),
  count: formatCount(filterCounts.value[key] || 0),
  active: selection.value === `filter:${key}`,
  pick: () => pickFilter(key),
});

const mainFilters = computed(() =>
  MAIN_FILTERS.filter(filter => !(isMine.value && filter.hideOnMine)).map(
    toFilterItem
  )
);
const relatedFilters = computed(() => RELATED_FILTERS.map(toFilterItem));

const groupCount = count => (isMine.value ? 0 : formatCount(count));

const groups = computed(() => [
  {
    key: 'folders',
    label: t('SIDEBAR.CUSTOM_VIEWS_FOLDER'),
    section: SIDEBAR_SORT_SECTIONS.FOLDERS,
    items: sortSidebarItems(folders.value, {
      sortBy: sortFor(SIDEBAR_SORT_SECTIONS.FOLDERS),
      labelKey: folder => folder.name,
      unreadCountKey: folder => getFolderUnreadCount.value(folder.id),
    }).map(folder => ({
      key: `folder:${folder.id}`,
      label: folder.name,
      icon: 'i-lucide-folder',
      count: groupCount(getFolderUnreadCount.value(folder.id)),
      pick: () =>
        router.push({
          name: 'folder_conversations',
          params: { accountId: route.params.accountId, id: folder.id },
        }),
    })),
  },
  {
    key: 'teams',
    label: t('SIDEBAR.TEAMS'),
    section: SIDEBAR_SORT_SECTIONS.TEAMS,
    items: sortSidebarItems(teams.value, {
      sortBy: sortFor(SIDEBAR_SORT_SECTIONS.TEAMS),
      labelKey: team => team.name,
      unreadCountKey: team => getTeamUnreadCount.value(team.id),
    }).map(team => ({
      key: `team:${team.id}`,
      label: team.name,
      icon: 'i-lucide-users',
      count: groupCount(getTeamUnreadCount.value(team.id)),
      pick: () => goToList({ ...scopeQuery(), team_id: String(team.id) }),
    })),
  },
  {
    key: 'labels',
    label: t('SIDEBAR.LABELS'),
    section: SIDEBAR_SORT_SECTIONS.LABELS,
    items: sortSidebarItems(labels.value, {
      sortBy: sortFor(SIDEBAR_SORT_SECTIONS.LABELS),
      labelKey: label => label.title,
      unreadCountKey: label => getLabelUnreadCount.value(label.id),
    }).map(label => ({
      key: `label:${label.title}`,
      label: label.title,
      color: label.color,
      count: groupCount(getLabelUnreadCount.value(label.id)),
      pick: () => goToList({ ...scopeQuery(), label: label.title }),
    })),
  },
]);

const openGroups = ref({ folders: false, teams: false, labels: true });
const isGroupOpen = group =>
  openGroups.value[group.key] ||
  group.items.some(item => item.key === selection.value);
const toggleGroup = group => {
  openGroups.value = {
    ...openGroups.value,
    [group.key]: !isGroupOpen(group),
  };
};

const sortedInboxes = computed(() =>
  sortSidebarItems(inboxes.value, {
    sortBy: sortFor(SIDEBAR_SORT_SECTIONS.CHANNELS),
    labelKey: inbox => inbox.name,
    unreadCountKey: inbox => getInboxUnreadCount.value(inbox.id),
  })
);

const activeInboxName = computed(
  () =>
    inboxes.value.find(inbox => String(inbox.id) === activeInboxId.value)
      ?.name || t('CHAT_LIST.FILTER_PANEL.ALL_CHANNELS')
);

const inboxChips = computed(() =>
  sortedInboxes.value.map(inbox => ({
    inbox,
    active: String(inbox.id) === activeInboxId.value,
    count: groupCount(getInboxUnreadCount.value(inbox.id)),
  }))
);

const showInboxMenu = ref(false);
const inboxMenuItems = computed(() => [
  {
    label: t('CHAT_LIST.FILTER_PANEL.ALL_CHANNELS'),
    action: 'inbox',
    value: '',
    isSelected: !activeInboxId.value,
  },
  ...sortedInboxes.value.map(inbox => ({
    label: inbox.name,
    action: 'inbox',
    value: inbox.id,
    isSelected: String(inbox.id) === activeInboxId.value,
  })),
]);

const onInboxMenuAction = ({ value }) => {
  showInboxMenu.value = false;
  pickInbox(value);
};

const itemClass = active =>
  active
    ? 'bg-n-teal-3 text-n-teal-11 font-semibold'
    : 'text-n-slate-12 font-medium hover:bg-n-alpha-2';

const countClass = (active, isAlert) => {
  if (active) return 'bg-n-teal-5 text-n-teal-12';
  if (isAlert) return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-alpha-2 text-n-slate-11';
};
</script>

<template>
  <aside
    v-on-click-outside="[
      () => overlay && closePanel(),
      {
        ignore: [
          '[data-filter-panel-toggle]',
          '[data-popover-content]',
          '[data-popover-backdrop]',
        ],
      },
    ]"
    :aria-label="title"
    class="flex flex-col flex-shrink-0 w-[252px] h-full min-h-0 border-e bg-n-surface-1 border-n-weak"
    :class="{ 'absolute inset-y-0 start-0 z-30 shadow-xl': overlay }"
  >
    <div
      class="flex items-center justify-between flex-shrink-0 h-14 border-b ps-4 pe-2.5 border-n-weak"
    >
      <h2 class="text-base font-bold truncate text-n-slate-12">
        {{ title }}
      </h2>
      <Button
        v-tooltip.bottom="t('CHAT_LIST.FILTER_PANEL.COLLAPSE')"
        icon="i-lucide-panel-left-close"
        slate
        ghost
        sm
        :aria-label="t('CHAT_LIST.FILTER_PANEL.COLLAPSE')"
        @click="closePanel"
      />
    </div>

    <div class="flex items-center gap-1 px-3 pt-3 pb-1">
      <div
        v-on-click-outside="() => (showInboxMenu = false)"
        class="relative flex-1 min-w-0"
      >
        <button
          type="button"
          class="flex items-center justify-between w-full h-9 gap-2 px-2.5 text-sm font-medium border rounded-lg text-n-slate-12 border-n-weak bg-n-solid-1 hover:bg-n-alpha-1"
          :aria-expanded="showInboxMenu"
          @click="showInboxMenu = !showInboxMenu"
        >
          <span class="flex items-center min-w-0 gap-2">
            <span class="i-lucide-inbox size-4 shrink-0 text-n-slate-11" />
            <span class="truncate">{{ activeInboxName }}</span>
          </span>
          <span class="i-lucide-chevron-down size-4 shrink-0 text-n-slate-10" />
        </button>
        <DropdownMenu
          v-if="showInboxMenu"
          :menu-items="inboxMenuItems"
          show-search
          :search-placeholder="t('CHAT_LIST.FILTER_PANEL.SEARCH_CHANNELS')"
          class="w-full mt-1 top-full max-h-80"
          @action="onInboxMenuAction"
        />
      </div>
      <SidebarSortMenu
        :active-sort="sortFor(SIDEBAR_SORT_SECTIONS.CHANNELS)"
        :options="sortOptionsFor(SIDEBAR_SORT_SECTIONS.CHANNELS)"
        :open-on-hover="false"
        @sort="sortBy => setSort(SIDEBAR_SORT_SECTIONS.CHANNELS, sortBy)"
      />
    </div>

    <div
      class="flex flex-shrink-0 gap-1 px-2.5 pt-2 pb-3 overflow-x-auto border-b no-scrollbar border-n-weak"
    >
      <button
        type="button"
        class="flex flex-col items-center flex-shrink-0 w-11 gap-1"
        :aria-pressed="!activeInboxId"
        :title="t('CHAT_LIST.FILTER_PANEL.ALL_CHANNELS')"
        @click="pickInbox('')"
      >
        <span
          class="grid rounded-full size-9 place-items-center bg-n-alpha-2 text-n-slate-11"
          :class="{
            'ring-2 ring-n-teal-9 ring-offset-2 ring-offset-n-surface-1':
              !activeInboxId,
          }"
        >
          <span class="i-lucide-users size-4" />
        </span>
        <span
          class="text-[11px] truncate max-w-11"
          :class="
            !activeInboxId
              ? 'font-semibold text-n-teal-11'
              : 'text-n-slate-11 font-medium'
          "
        >
          {{ t('CHAT_LIST.FILTER_PANEL.ALL') }}
        </span>
      </button>
      <button
        v-for="chip in inboxChips"
        :key="chip.inbox.id"
        type="button"
        class="flex flex-col items-center flex-shrink-0 w-11 gap-1"
        :aria-pressed="chip.active"
        :title="chip.inbox.name"
        @click="pickInbox(chip.inbox.id)"
      >
        <span
          class="relative grid rounded-full size-9 place-items-center bg-n-alpha-2"
          :class="{
            'ring-2 ring-n-teal-9 ring-offset-2 ring-offset-n-surface-1':
              chip.active,
          }"
        >
          <ChannelIcon :inbox="chip.inbox" use-brand-icon class="size-5" />
          <span
            v-if="chip.inbox.reauthorization_required"
            v-tooltip.top="t('SIDEBAR.REAUTHORIZE')"
            class="absolute grid rounded-full -top-1 -end-1 size-4 place-items-center bg-n-ruby-9"
          >
            <span class="text-white i-lucide-alert-triangle size-2.5" />
          </span>
          <span
            v-else-if="chip.count"
            class="absolute grid h-4 px-1 text-[10px] font-bold leading-none text-white rounded-full -top-1 -end-1.5 min-w-4 place-items-center bg-n-teal-9"
          >
            {{ chip.count }}
          </span>
        </span>
        <span
          class="text-[11px] truncate max-w-11"
          :class="
            chip.active
              ? 'font-semibold text-n-teal-11'
              : 'text-n-slate-11 font-medium'
          "
        >
          {{ chip.inbox.name }}
        </span>
      </button>
    </div>

    <nav
      class="flex flex-col flex-1 min-h-0 gap-px px-2 pt-2.5 pb-4 overflow-y-auto"
    >
      <button
        v-for="item in mainFilters"
        :key="item.key"
        type="button"
        class="flex items-center justify-between flex-shrink-0 h-[34px] gap-2 ps-2.5 pe-2 text-[13.5px] rounded-lg text-start"
        :class="itemClass(item.active)"
        :aria-current="item.active ? 'page' : undefined"
        @click="item.pick"
      >
        <span class="flex items-center min-w-0 gap-2.5">
          <span class="size-[17px] shrink-0" :class="item.icon" />
          <span class="truncate">{{ item.label }}</span>
        </span>
        <span
          v-if="item.count"
          class="inline-grid h-5 min-w-[22px] px-1.5 place-items-center rounded-full text-[11.5px] font-semibold"
          :class="countClass(item.active, item.isAlert)"
        >
          {{ item.count }}
        </span>
      </button>

      <span
        class="px-2.5 pt-3.5 pb-1.5 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
      >
        {{ t('CHAT_LIST.FILTER_PANEL.RELATED') }}
      </span>
      <button
        v-for="item in relatedFilters"
        :key="item.key"
        type="button"
        class="flex items-center justify-between flex-shrink-0 h-[34px] gap-2 ps-2.5 pe-2 text-[13.5px] rounded-lg text-start"
        :class="itemClass(item.active)"
        :aria-current="item.active ? 'page' : undefined"
        @click="item.pick"
      >
        <span class="flex items-center min-w-0 gap-2.5">
          <span class="size-[17px] shrink-0" :class="item.icon" />
          <span class="truncate">{{ item.label }}</span>
        </span>
        <span
          v-if="item.count"
          class="inline-grid h-5 min-w-[22px] px-1.5 place-items-center rounded-full text-[11.5px] font-semibold"
          :class="countClass(item.active, false)"
        >
          {{ item.count }}
        </span>
      </button>

      <div
        v-for="group in groups"
        :key="group.key"
        class="flex flex-col flex-shrink-0 gap-px mt-2"
      >
        <div class="flex items-center gap-0.5">
          <button
            type="button"
            class="flex items-center flex-1 h-[30px] gap-1.5 px-2 text-[11px] font-semibold tracking-wide uppercase rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
            :aria-expanded="isGroupOpen(group)"
            @click="toggleGroup(group)"
          >
            <span
              class="i-lucide-chevron-down size-3.5 transition-transform"
              :class="{ '-rotate-90': !isGroupOpen(group) }"
            />
            {{ group.label }}
          </button>
          <SidebarSortMenu
            :active-sort="sortFor(group.section)"
            :options="sortOptionsFor(group.section)"
            :open-on-hover="false"
            @sort="sortBy => setSort(group.section, sortBy)"
          />
        </div>
        <template v-if="isGroupOpen(group)">
          <button
            v-for="item in group.items"
            :key="item.key"
            type="button"
            class="flex items-center h-8 gap-2.5 ps-3 pe-2 text-[13.5px] rounded-lg text-start"
            :class="itemClass(item.key === selection)"
            :aria-current="item.key === selection ? 'page' : undefined"
            @click="item.pick"
          >
            <span
              v-if="item.color"
              class="mx-1 rounded-full size-2 shrink-0"
              :style="{ backgroundColor: item.color }"
            />
            <span v-else class="size-4 shrink-0" :class="item.icon" />
            <span class="flex-1 min-w-0 truncate">{{ item.label }}</span>
            <span v-if="item.count" class="text-xs font-medium text-n-slate-11">
              {{ item.count }}
            </span>
          </button>
        </template>
      </div>
    </nav>
  </aside>
</template>
