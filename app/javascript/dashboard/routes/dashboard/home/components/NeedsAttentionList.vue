<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import VipBadge from 'dashboard/components-next/Contacts/VipBadge.vue';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import wootConstants from 'dashboard/constants/globals';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const activeTab = ref('all');

// Team-wide open queue (no assignee filter): longest-waiting first,
// non-waiting conversations last (see app/finders/conversation_finder.rb:12
// and app/models/concerns/sort_handler.rb:21: `ORDER BY (waiting_since IS
// NULL), waiting_since ASC, created_at ASC`). This card is about urgency, so
// it must be ordered by the same quantity its pill shows.
const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const response = await ConversationApi.get({
    status: 'open',
    page: 1,
    sortBy: 'waiting_since_asc',
  });
  return {
    rows: response.data.data.payload.slice(0, 10),
    // `meta.all_count` is the account-wide open total; fall back to the
    // fetched slice when the shape is unexpected.
    total: response.data.meta?.all_count ?? response.data.data.payload.length,
  };
});

const {
  data: vipData,
  isLoading: isVipLoading,
  hasError: hasVipError,
  load: loadVip,
} = useAsyncBlock(async () => {
  const response = await ConversationApi.get({
    status: 'open',
    assigneeType: wootConstants.ASSIGNEE_TYPE.VIP,
    page: 1,
    sortBy: 'waiting_since_asc',
  });
  const payload = response.data.data.payload;
  return {
    rows: payload.slice(0, 10),
    total: response.data.data.meta?.vip_count ?? payload.length,
  };
});

// `waiting_since` (jbuilder: `conversation.waiting_since.to_i.to_i`) is 0,
// not null, for a conversation that isn't currently waiting on an agent —
// treat that (and any other non-positive or malformed value) as "not
// waiting" rather than a huge or negative minute count.
const waitedMinutes = conversation => {
  const waitingSince = conversation.waiting_since;
  if (!waitingSince) return null;
  const minutes = Math.floor((Date.now() / 1000 - waitingSince) / 60);
  return Math.max(0, minutes);
};

const pillClass = minutes => {
  if (minutes >= 240) return 'bg-n-ruby-3 text-n-ruby-11';
  if (minutes >= 60) return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-alpha-2 text-n-slate-11';
};

const priorityBadgeClass = priority => {
  if (priority === 'urgent' || priority === 'high') {
    return 'bg-n-ruby-3 text-n-ruby-11';
  }
  if (priority === 'medium') return 'bg-n-alpha-2 text-n-brand';
  return 'bg-n-alpha-2 text-n-slate-11';
};

// `meta.sender` isn't guaranteed on every row (mirrors the existing
// `row.messages?.[0]?.content` guard in the template) — fall back to a
// translated placeholder rather than letting the render function throw on a
// missing contact.
const senderName = row =>
  row.meta?.sender?.name || t('HOME.ATTENTION.UNKNOWN_CONTACT');

const isVip = row => !!row.meta?.sender?.vip;

const rows = computed(() => data.value?.rows ?? []);
const total = computed(() => data.value?.total ?? 0);
const vipRows = computed(() => vipData.value?.rows ?? []);
const vipTotal = computed(() => vipData.value?.total ?? 0);

const slaRows = computed(() =>
  rows.value.filter(row => {
    const minutes = waitedMinutes(row);
    return minutes !== null && minutes >= 60;
  })
);

const isVipTab = computed(() => activeTab.value === 'vip');

// `tone` highlights a tab only while it has something to act on, so an empty
// tab stays neutral instead of permanently drawing the eye.
const tabs = computed(() => [
  { key: 'all', i18nKey: 'TAB_ALL', count: rows.value.length, tone: null },
  {
    key: 'sla',
    i18nKey: 'TAB_SLA',
    count: slaRows.value.length,
    tone: 'ruby',
  },
  { key: 'vip', i18nKey: 'TAB_VIP', count: vipTotal.value, tone: 'amber' },
]);

const filtered = computed(() => {
  if (activeTab.value === 'sla') return slaRows.value;
  if (isVipTab.value) return vipRows.value;
  return rows.value;
});

const isListLoading = computed(() =>
  isVipTab.value ? isVipLoading.value : isLoading.value
);
const hasListError = computed(() =>
  isVipTab.value ? hasVipError.value : hasError.value
);
const listTotal = computed(() =>
  isVipTab.value ? vipTotal.value : rows.value.length
);

const TONE_CLASSES = {
  ruby: {
    text: 'text-n-ruby-11',
    idle: 'bg-n-ruby-3 hover:bg-n-ruby-4',
    dot: 'bg-n-ruby-9',
  },
  amber: {
    text: 'text-n-amber-11',
    idle: 'bg-n-amber-3 hover:bg-n-amber-4',
    dot: 'bg-n-amber-9',
  },
};

const tabTone = tab =>
  tab.tone && tab.count > 0 ? TONE_CLASSES[tab.tone] : null;

const tabButtonClass = tab => {
  const tone = tabTone(tab);
  if (activeTab.value === tab.key) {
    return [
      'bg-white shadow-sm dark:bg-n-solid-2',
      tone ? tone.text : 'text-n-slate-12',
    ];
  }
  if (tone) return [tone.idle, tone.text];
  return 'text-n-slate-11 hover:text-n-slate-12';
};

const reload = () => (isVipTab.value ? loadVip() : load());

const timeAgo = row => {
  const createdAt = row.messages?.[0]?.created_at;
  if (!createdAt) return '';
  return shortTimestamp(dynamicTime(createdAt));
};

const assigneeName = row => row.meta?.assignee?.name ?? '';

// The conversations index endpoint serializes each conversation's `id` field
// as `conversation.display_id` (see
// app/views/api/v1/conversations/partials/_conversation.json.jbuilder), and
// the conversation show route resolves `:conversation_id` via
// `find_by!(display_id: ...)` (conversations/base_controller.rb). So `row.id`
// here already IS the display id the route expects.
const openConversation = id =>
  router.push({
    name: 'inbox_conversation',
    params: { accountId: route.params.accountId, conversation_id: id },
  });

const viewAllRoute = computed(() => ({
  name: 'home',
  params: { accountId: route.params.accountId },
  ...(isVipTab.value && { query: { tab: wootConstants.ASSIGNEE_TYPE.VIP } }),
}));

onMounted(() => {
  load();
  loadVip();
});
</script>

<template>
  <div
    class="rounded-2xl bg-white border border-n-weak shadow-sm dark:bg-n-solid-2 flex flex-col overflow-hidden"
  >
    <div
      class="p-5 border-b border-n-weak flex flex-wrap items-center justify-between gap-3"
    >
      <div>
        <h2 class="text-base font-semibold tracking-tight text-n-slate-12">
          {{ t('HOME.ATTENTION.TITLE') }}
        </h2>
        <p class="text-[13px] text-n-slate-11">
          {{ t('HOME.ATTENTION.SUBTITLE') }}
        </p>
      </div>
      <div
        class="flex items-center gap-1 p-1 rounded-xl bg-n-alpha-1 border border-n-weak"
      >
        <button
          v-for="tab in tabs"
          :key="tab.key"
          type="button"
          class="flex items-center gap-1.5 px-3 py-1 rounded-lg text-[13px] font-medium"
          :class="tabButtonClass(tab)"
          @click="activeTab = tab.key"
        >
          <span
            v-if="tabTone(tab)"
            class="rounded-full size-1.5"
            :class="tabTone(tab).dot"
          />
          {{ t(`HOME.ATTENTION.${tab.i18nKey}`, { count: tab.count }) }}
        </button>
      </div>
    </div>

    <div v-if="isListLoading" class="flex flex-col gap-1 p-3">
      <div
        v-for="n in 4"
        :key="n"
        class="w-full h-16 rounded-xl bg-n-alpha-2 animate-pulse"
      />
    </div>

    <button
      v-else-if="hasListError"
      class="self-start m-5 text-[13px] text-n-brand hover:underline"
      @click="reload"
    >
      {{ t('HOME.RETRY') }}
    </button>

    <p
      v-else-if="!filtered.length"
      class="w-full py-8 text-sm text-center text-n-slate-11"
    >
      {{ t('HOME.ATTENTION.EMPTY') }}
    </p>

    <ul v-else class="divide-y divide-n-weak">
      <li
        v-for="row in filtered"
        :key="row.id"
        class="group p-5 flex flex-col gap-3 cursor-pointer hover:bg-n-alpha-1 md:flex-row md:items-center md:justify-between"
        @click="openConversation(row.id)"
      >
        <div class="flex items-start gap-3 min-w-0">
          <Avatar
            :name="senderName(row)"
            :src="row.meta?.sender?.thumbnail"
            :size="44"
            :inbox="{ channel_type: row.meta?.channel }"
          />
          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span
                class="text-[15px] font-semibold tracking-tight text-n-slate-12"
              >
                {{ senderName(row) }}
              </span>
              <VipBadge v-if="isVip(row)" />
              <span
                v-if="row.priority"
                class="px-2 py-0.5 rounded-full text-[11px] font-semibold uppercase tracking-wide"
                :class="priorityBadgeClass(row.priority)"
              >
                {{ row.priority }}
              </span>
              <span
                v-if="waitedMinutes(row) !== null"
                class="px-2 py-0.5 rounded-full text-[11px] font-medium font-mono"
                :class="pillClass(waitedMinutes(row))"
              >
                {{
                  t('HOME.ATTENTION.WAITED', { minutes: waitedMinutes(row) })
                }}
              </span>
            </div>
            <p class="text-sm truncate text-n-slate-12 mt-1">
              {{ row.messages?.[0]?.content }}
            </p>
            <p class="flex items-center gap-2 text-xs text-n-slate-11 mt-1.5">
              <span v-if="timeAgo(row)">{{ timeAgo(row) }}</span>
              <span
                v-if="assigneeName(row)"
                class="flex items-center gap-1 font-medium text-n-slate-12"
              >
                <span class="i-lucide-user size-3" />
                {{ assigneeName(row) }}
              </span>
              <span v-else class="flex items-center gap-1 text-n-slate-11">
                <span class="i-lucide-user-x size-3" />
                {{ t('HOME.ATTENTION.UNASSIGNED') }}
              </span>
            </p>
          </div>
        </div>
        <div
          class="flex items-center gap-2 shrink-0 md:opacity-0 md:group-hover:opacity-100"
        >
          <button
            type="button"
            class="px-3 py-1.5 rounded-lg bg-white border border-n-weak text-[13px] font-medium text-n-slate-12 shadow-sm hover:bg-n-alpha-1 dark:bg-n-solid-2"
            @click.stop="openConversation(row.id)"
          >
            {{ t('HOME.ATTENTION.REPLY') }}
          </button>
        </div>
      </li>
    </ul>

    <div
      class="px-5 py-3.5 border-t border-n-weak bg-n-alpha-1 flex items-center justify-between text-[13px]"
    >
      <span class="text-n-slate-11">
        {{
          t('HOME.ATTENTION.SHOWING', {
            shown: filtered.length,
            total: listTotal,
          })
        }}
      </span>
      <router-link
        :to="viewAllRoute"
        class="font-medium text-n-brand hover:underline"
      >
        {{ t('HOME.ATTENTION.VIEW_ALL', { count: total }) }}
      </router-link>
    </div>
  </div>
</template>
