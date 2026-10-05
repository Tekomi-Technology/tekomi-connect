<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import reportsAPI from 'dashboard/api/conversationEmotionReports';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import ReportHeader from './components/ReportHeader.vue';

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');
const rows = ref([]);
const counts = ref({});
const meta = ref({ current_page: 1, total_pages: 1, total_entries: 0 });
const isLoading = ref(false);

const filters = reactive({
  emotion: '',
  status: '',
  action_status: '',
  inbox_id: '',
  assignee_id: '',
  period: '30',
  page: 1,
  limit: 50,
});

const options = computed(() => ({
  emotion: ['vui', 'trung tính', 'buồn', 'khó chịu', 'gay gắt'],
  status: ['pending', 'processing', 'completed', 'failed', 'skipped'],
  action_status: ['none', 'needs_follow_up', 'in_progress', 'resolved'],
  inbox_id: inboxes.value.map(inbox => ({
    value: String(inbox.id),
    label: inbox.name,
  })),
  assignee_id: agents.value.map(agent => ({
    value: String(agent.id),
    label: agent.available_name || agent.name,
  })),
  period: ['7', '30', '90', 'all'],
}));

const emotionClasses = {
  blue: 'bg-n-blue-3 text-n-blue-11 border-n-blue-7',
  green: 'bg-n-teal-3 text-n-teal-11 border-n-teal-7',
  purple: 'bg-n-purple-3 text-n-purple-11 border-n-purple-7',
  orange: 'bg-n-amber-3 text-n-amber-11 border-n-amber-7',
  red: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-7',
};

const requestParams = () => {
  const params = Object.fromEntries(
    Object.entries(filters).filter(
      ([key, value]) => value !== '' && key !== 'period'
    )
  );
  if (filters.period !== 'all') {
    params.since =
      Math.floor(Date.now() / 1000) - Number(filters.period) * 86400;
  }
  return params;
};

const fetchReports = async () => {
  isLoading.value = true;
  try {
    const { data } = await reportsAPI.getReports(requestParams());
    rows.value = data.data;
    counts.value = data.counts;
    meta.value = data.meta;
  } catch {
    useAlert(t('CONVERSATION_EMOTION_REPORTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const updateActionStatus = async (row, actionStatus) => {
  const previousStatus = row.action_status;
  row.action_status = actionStatus;
  try {
    const { data } = await reportsAPI.updateReport(row.id, {
      action_status: actionStatus,
    });
    Object.assign(row, data);
  } catch {
    row.action_status = previousStatus;
    useAlert(t('CONVERSATION_EMOTION_REPORTS.UPDATE_ERROR'));
  }
};

const label = (group, value) =>
  value
    ? t(`CONVERSATION_EMOTION_REPORTS.${group}.${value.toUpperCase()}`)
    : t('CONVERSATION_EMOTION_REPORTS.EMPTY_VALUE');

const emotionClass = row =>
  emotionClasses[row.emotion_tag?.color] ||
  'bg-n-slate-3 text-n-slate-11 border-n-slate-7';

const formatDate = value =>
  value
    ? new Intl.DateTimeFormat(undefined, {
        dateStyle: 'short',
        timeStyle: 'medium',
      }).format(new Date(value))
    : t('CONVERSATION_EMOTION_REPORTS.EMPTY_VALUE');

const conversationPath = conversationId =>
  `/app/accounts/${route.params.accountId}/conversations/${conversationId}`;

const conversationLabel = conversationId =>
  t('CONVERSATION_EMOTION_REPORTS.CONVERSATION_ID', { id: conversationId });

const changePage = page => {
  if (page < 1 || page > meta.value.total_pages || page === filters.page)
    return;
  filters.page = page;
  fetchReports();
};

watch(
  () => [
    filters.emotion,
    filters.status,
    filters.action_status,
    filters.inbox_id,
    filters.assignee_id,
    filters.period,
  ],
  () => {
    filters.page = 1;
    fetchReports();
  }
);

onMounted(() => {
  store.dispatch('agents/get');
  fetchReports();
});
</script>

<template>
  <ReportHeader
    :header-title="t('CONVERSATION_EMOTION_REPORTS.HEADER')"
    :header-description="t('CONVERSATION_EMOTION_REPORTS.DESCRIPTION')"
  >
    <template #filters>
      <div class="grid w-full grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-6">
        <label
          v-for="filter in ['emotion', 'status', 'action_status']"
          :key="filter"
          class="flex flex-col gap-1 text-xs text-n-slate-11"
        >
          {{
            t(`CONVERSATION_EMOTION_REPORTS.FILTERS.${filter.toUpperCase()}`)
          }}
          <select
            v-model="filters[filter]"
            class="h-9 px-2 border rounded-lg border-n-weak bg-n-alpha-2 text-n-slate-12"
          >
            <option value="">
              {{ t('CONVERSATION_EMOTION_REPORTS.FILTERS.ALL') }}
            </option>
            <option
              v-for="value in options[filter]"
              :key="value"
              :value="value"
            >
              {{
                label(
                  filter === 'status' ? 'REPORT_STATUS' : filter.toUpperCase(),
                  value
                )
              }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-xs text-n-slate-11">
          {{ t('CONVERSATION_EMOTION_REPORTS.FILTERS.INBOX') }}
          <select
            v-model="filters.inbox_id"
            class="h-9 px-2 border rounded-lg border-n-weak bg-n-alpha-2 text-n-slate-12"
          >
            <option value="">
              {{ t('CONVERSATION_EMOTION_REPORTS.FILTERS.ALL') }}
            </option>
            <option
              v-for="item in options.inbox_id"
              :key="item.value"
              :value="item.value"
            >
              {{ item.label }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-xs text-n-slate-11">
          {{ t('CONVERSATION_EMOTION_REPORTS.FILTERS.ASSIGNEE') }}
          <select
            v-model="filters.assignee_id"
            class="h-9 px-2 border rounded-lg border-n-weak bg-n-alpha-2 text-n-slate-12"
          >
            <option value="">
              {{ t('CONVERSATION_EMOTION_REPORTS.FILTERS.ALL') }}
            </option>
            <option
              v-for="item in options.assignee_id"
              :key="item.value"
              :value="item.value"
            >
              {{ item.label }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-xs text-n-slate-11">
          {{ t('CONVERSATION_EMOTION_REPORTS.FILTERS.PERIOD') }}
          <select
            v-model="filters.period"
            class="h-9 px-2 border rounded-lg border-n-weak bg-n-alpha-2 text-n-slate-12"
          >
            <option v-for="value in options.period" :key="value" :value="value">
              {{ label('PERIOD', value) }}
            </option>
          </select>
        </label>
      </div>
    </template>
  </ReportHeader>

  <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
    <div
      v-for="card in ['total', 'completed', 'needs_follow_up', 'aggressive']"
      :key="card"
      class="flex flex-col gap-2 p-4 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
    >
      <div
        class="text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
      >
        {{ t(`CONVERSATION_EMOTION_REPORTS.CARDS.${card.toUpperCase()}`) }}
      </div>
      <div class="text-3xl font-semibold tracking-tight text-n-slate-12">
        {{
          card === 'total'
            ? counts.total || 0
            : card === 'completed'
              ? counts.report_status?.completed || 0
              : card === 'needs_follow_up'
                ? counts.action_status?.needs_follow_up || 0
                : counts.emotion?.['gay gắt'] || 0
        }}
      </div>
    </div>
  </div>

  <div
    class="overflow-x-auto bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
  >
    <table class="w-full text-sm text-left">
      <thead
        class="text-xs border-b bg-n-alpha-2 border-n-weak text-n-slate-10"
      >
        <tr>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.TIME') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.CUSTOMER') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.CHANNEL') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.ASSIGNEE') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.EMOTION') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.REASON') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.ACTION_STATUS') }}
          </th>
          <th class="p-3">
            {{ t('CONVERSATION_EMOTION_REPORTS.TABLE.CONVERSATION') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="isLoading">
          <td colspan="8" class="p-8 text-center text-n-slate-10">
            {{ t('CONVERSATION_EMOTION_REPORTS.LOADING') }}
          </td>
        </tr>
        <tr v-else-if="!rows.length">
          <td colspan="8" class="p-8 text-center text-n-slate-10">
            {{ t('CONVERSATION_EMOTION_REPORTS.EMPTY') }}
          </td>
        </tr>
        <template v-else>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-b last:border-0 border-n-weak text-n-slate-12"
          >
            <td class="p-3 whitespace-nowrap">
              {{ formatDate(row.resolved_at || row.created_at) }}
            </td>
            <td class="p-3 font-medium">{{ row.contact_name }}</td>
            <td class="p-3">{{ row.inbox_name }}</td>
            <td class="p-3">
              {{
                row.assignee_name ||
                t('CONVERSATION_EMOTION_REPORTS.EMPTY_VALUE')
              }}
            </td>
            <td class="p-3">
              <span
                v-if="row.emotion_tag"
                :class="emotionClass(row)"
                class="inline-flex px-2 py-1 text-xs font-medium border rounded-full whitespace-nowrap"
              >
                {{ row.emotion_tag.label }}
              </span>
              <span v-else class="text-n-slate-9">{{
                label('REPORT_STATUS', row.status)
              }}</span>
            </td>
            <td class="max-w-sm p-3 text-xs text-n-slate-11">
              {{
                row.reason ||
                row.error_message ||
                t('CONVERSATION_EMOTION_REPORTS.EMPTY_VALUE')
              }}
            </td>
            <td class="p-3">
              <select
                :value="row.action_status"
                class="h-8 px-2 text-xs border rounded-lg border-n-weak bg-n-alpha-2"
                @change="updateActionStatus(row, $event.target.value)"
              >
                <option
                  v-for="value in options.action_status"
                  :key="value"
                  :value="value"
                >
                  {{ label('ACTION_STATUS', value) }}
                </option>
              </select>
            </td>
            <td class="p-3">
              <router-link
                :to="conversationPath(row.conversation_id)"
                class="font-medium text-n-brand hover:underline"
              >
                {{ conversationLabel(row.conversation_id) }}
              </router-link>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>

  <div
    v-if="meta.total_pages > 1"
    class="flex items-center justify-between py-4 text-sm text-n-slate-11"
  >
    <span>{{
      t('CONVERSATION_EMOTION_REPORTS.PAGINATION', {
        current: meta.current_page,
        total: meta.total_pages,
        count: meta.total_entries,
      })
    }}</span>
    <div class="flex gap-2">
      <button
        class="px-3 py-1.5 border rounded-lg border-n-weak disabled:opacity-40"
        :disabled="meta.current_page <= 1"
        @click="changePage(meta.current_page - 1)"
      >
        {{ t('CONVERSATION_EMOTION_REPORTS.PREVIOUS') }}
      </button>
      <button
        class="px-3 py-1.5 border rounded-lg border-n-weak disabled:opacity-40"
        :disabled="meta.current_page >= meta.total_pages"
        @click="changePage(meta.current_page + 1)"
      >
        {{ t('CONVERSATION_EMOTION_REPORTS.NEXT') }}
      </button>
    </div>
  </div>
</template>
