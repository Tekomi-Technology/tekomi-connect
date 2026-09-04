<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
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

const isVip = row =>
  (row.labels ?? []).some(label => String(label).toLowerCase() === 'vip');

const rows = computed(() => data.value?.rows ?? []);
const total = computed(() => data.value?.total ?? 0);

const counts = computed(() => ({
  all: rows.value.length,
  sla: rows.value.filter(row => {
    const minutes = waitedMinutes(row);
    return minutes !== null && minutes >= 60;
  }).length,
  vip: rows.value.filter(isVip).length,
}));

const filtered = computed(() => {
  if (activeTab.value === 'sla') {
    return rows.value.filter(row => {
      const minutes = waitedMinutes(row);
      return minutes !== null && minutes >= 60;
    });
  }
  if (activeTab.value === 'vip') return rows.value.filter(isVip);
  return rows.value;
});

const tabButtonClass = tab =>
  activeTab.value === tab
    ? 'bg-white text-n-slate-12 shadow-sm dark:bg-n-solid-2'
    : 'text-n-slate-11 hover:text-n-slate-12';

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

onMounted(load);
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
          type="button"
          class="px-3 py-1 rounded-lg text-[13px] font-medium"
          :class="tabButtonClass('all')"
          @click="activeTab = 'all'"
        >
          {{ t('HOME.ATTENTION.TAB_ALL', { count: counts.all }) }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[13px] font-medium"
          :class="tabButtonClass('sla')"
          @click="activeTab = 'sla'"
        >
          {{ t('HOME.ATTENTION.TAB_SLA', { count: counts.sla }) }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[13px] font-medium"
          :class="tabButtonClass('vip')"
          @click="activeTab = 'vip'"
        >
          {{ t('HOME.ATTENTION.TAB_VIP', { count: counts.vip }) }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="flex flex-col gap-1 p-3">
      <div
        v-for="n in 4"
        :key="n"
        class="w-full h-16 rounded-xl bg-n-alpha-2 animate-pulse"
      />
    </div>

    <button
      v-else-if="hasError"
      class="self-start m-5 text-[13px] text-n-brand hover:underline"
      @click="load"
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
            total: rows.length,
          })
        }}
      </span>
      <router-link
        :to="{ name: 'home', params: { accountId: route.params.accountId } }"
        class="font-medium text-[#4F46E5] hover:underline"
      >
        {{ t('HOME.ATTENTION.VIEW_ALL', { count: total }) }}
      </router-link>
    </div>
  </div>
</template>
