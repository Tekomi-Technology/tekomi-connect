<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import ConversationApi from 'dashboard/api/inbox/conversation';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const response = await ConversationApi.get({
    status: 'open',
    assigneeType: 'me',
    page: 1,
    // Longest-waiting first, non-waiting conversations last (see
    // app/finders/conversation_finder.rb:12 and
    // app/models/concerns/sort_handler.rb:21: `ORDER BY (waiting_since IS
    // NULL), waiting_since ASC, created_at ASC`). This card is about
    // urgency, so it must be ordered by the same quantity its pill shows.
    sortBy: 'waiting_since_asc',
  });
  return response.data.data.payload.slice(0, 6);
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

// `meta.sender` isn't guaranteed on every row (mirrors the existing
// `row.messages?.[0]?.content` guard on the line below it in the template) —
// fall back to a translated placeholder rather than letting the render
// function throw on a missing contact.
const senderName = row =>
  row.meta?.sender?.name || t('HOME.ATTENTION.UNKNOWN_CONTACT');

const rows = computed(() => data.value ?? []);

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
  <CardLayout>
    <div class="flex items-center justify-between w-full">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('HOME.ATTENTION.TITLE') }}
      </h2>
      <router-link
        :to="{ name: 'home' }"
        class="text-xs text-n-brand hover:underline"
      >
        {{ t('HOME.ATTENTION.VIEW_ALL') }}
      </router-link>
    </div>

    <div v-if="isLoading" class="flex flex-col w-full gap-3">
      <div
        v-for="n in 4"
        :key="n"
        class="w-full h-10 rounded bg-n-alpha-2 animate-pulse"
      />
    </div>

    <button
      v-else-if="hasError"
      class="self-start text-xs text-n-brand hover:underline"
      @click="load"
    >
      {{ t('HOME.RETRY') }}
    </button>

    <p
      v-else-if="!rows.length"
      class="w-full py-6 text-sm text-center text-n-slate-11"
    >
      {{ t('HOME.ATTENTION.EMPTY') }}
    </p>

    <ul v-else class="flex flex-col w-full divide-y divide-n-weak">
      <li
        v-for="row in rows"
        :key="row.id"
        class="flex items-center gap-3 py-2 cursor-pointer"
        @click="openConversation(row.id)"
      >
        <Avatar
          :name="senderName(row)"
          :src="row.meta?.sender?.thumbnail"
          :size="28"
          :inbox="{ channel_type: row.meta?.channel }"
        />
        <div class="flex-grow min-w-0">
          <p class="text-sm truncate text-n-slate-12">
            {{ senderName(row) }}
          </p>
          <p class="text-xs truncate text-n-slate-11">
            {{ row.messages?.[0]?.content }}
          </p>
        </div>
        <span
          v-if="waitedMinutes(row) !== null"
          class="flex-shrink-0 px-2 py-1 text-xs rounded-md"
          :class="pillClass(waitedMinutes(row))"
        >
          {{ t('HOME.ATTENTION.WAITED', { minutes: waitedMinutes(row) }) }}
        </span>
      </li>
    </ul>
  </CardLayout>
</template>
