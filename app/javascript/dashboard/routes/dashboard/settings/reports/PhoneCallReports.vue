<script setup>
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import phoneCallsAPI from 'dashboard/api/phoneCalls';
import { useAlert } from 'dashboard/composables';

import ReportHeader from './components/ReportHeader.vue';

const { t } = useI18n();
const route = useRoute();
const rows = ref([]);
const counts = ref({});
const meta = ref({ current_page: 1, total_pages: 1, total_entries: 0 });
const isLoading = ref(false);

const filters = reactive({
  call_status: '',
  emotion: '',
  status: '',
  action_status: '',
  purpose: '',
  direction: '',
  page: 1,
  limit: 50,
});

const options = computed(() => ({
  callStatus: [
    'completed',
    'missed',
    'busy',
    'no_answer',
    'rejected',
    'cancelled',
    'failed',
    'ringing',
    'in_progress',
  ],
  emotion: ['vui', 'trung tính', 'buồn', 'khó chịu', 'gay gắt'],
  reportStatus: [
    'pending',
    'processing',
    'completed',
    'failed',
    'not_analyzed',
  ],
  actionStatus: ['none', 'needs_follow_up', 'in_progress', 'resolved'],
  purpose: ['monitoring', 'follow_up', 'quality_review'],
  direction: ['inbound', 'outbound'],
}));

const emotionClasses = {
  blue: 'bg-n-blue-3 text-n-blue-11 border-n-blue-7',
  green: 'bg-n-teal-3 text-n-teal-11 border-n-teal-7',
  purple: 'bg-n-purple-3 text-n-purple-11 border-n-purple-7',
  orange: 'bg-n-amber-3 text-n-amber-11 border-n-amber-7',
  red: 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-7',
};

const fetchReports = async () => {
  isLoading.value = true;
  try {
    const params = Object.fromEntries(
      Object.entries(filters).filter(([, value]) => value !== '')
    );
    const { data } = await phoneCallsAPI.emotionReports(params);
    rows.value = data.data;
    counts.value = data.counts;
    meta.value = data.meta;
  } catch {
    useAlert(t('PHONE_CALL_REPORTS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const updateActionStatus = async (row, actionStatus) => {
  const previousStatus = row.action_status;
  row.action_status = actionStatus;
  try {
    const { data } = await phoneCallsAPI.updateEmotionReport(
      row.phone_call_id,
      {
        action_status: actionStatus,
      }
    );
    Object.assign(row, data);
  } catch {
    row.action_status = previousStatus;
    useAlert(t('PHONE_CALL_REPORTS.UPDATE_ERROR'));
  }
};

const emotionClass = row =>
  emotionClasses[row.emotion_tag?.color] ||
  'bg-n-slate-3 text-n-slate-11 border-n-slate-7';

const label = (group, value) =>
  value
    ? t(`PHONE_CALL_REPORTS.${group}.${value.toUpperCase()}`)
    : t('PHONE_CALL_REPORTS.EMPTY_VALUE');

const formatDate = value =>
  value
    ? new Intl.DateTimeFormat(undefined, {
        dateStyle: 'short',
        timeStyle: 'medium',
      }).format(new Date(value))
    : t('PHONE_CALL_REPORTS.EMPTY_VALUE');

const formatDuration = value => {
  if (value === null || value === undefined)
    return t('PHONE_CALL_REPORTS.EMPTY_VALUE');
  const minutes = Math.floor(value / 60);
  const seconds = value % 60;
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
};

const conversationPath = conversationId =>
  `/app/accounts/${route.params.accountId}/conversations/${conversationId}`;

const conversationLabel = conversationId =>
  t('PHONE_CALL_REPORTS.CONVERSATION_ID', { id: conversationId });

const changePage = page => {
  if (page < 1 || page > meta.value.total_pages || page === filters.page)
    return;
  filters.page = page;
  fetchReports();
};

watch(
  () => [
    filters.call_status,
    filters.emotion,
    filters.status,
    filters.action_status,
    filters.purpose,
    filters.direction,
  ],
  () => {
    filters.page = 1;
    fetchReports();
  }
);

onMounted(fetchReports);
</script>

<template>
  <ReportHeader
    :header-title="t('PHONE_CALL_REPORTS.HEADER')"
    :header-description="t('PHONE_CALL_REPORTS.DESCRIPTION')"
  />

  <div class="grid grid-cols-2 gap-3 mb-5 sm:grid-cols-4">
    <div class="p-4 border rounded-xl border-n-weak bg-n-solid-1">
      <div class="text-xs text-n-slate-10">
        {{ t('PHONE_CALL_REPORTS.TOTAL') }}
      </div>
      <div class="mt-1 text-2xl font-semibold text-n-slate-12">
        {{ counts.total || 0 }}
      </div>
    </div>
    <div class="p-4 border rounded-xl border-n-weak bg-n-solid-1">
      <div class="text-xs text-n-slate-10">
        {{ label('CALL_STATUS', 'completed') }}
      </div>
      <div class="mt-1 text-2xl font-semibold text-n-slate-12">
        {{ counts.call_status?.completed || 0 }}
      </div>
    </div>
    <div class="p-4 border rounded-xl border-n-weak bg-n-solid-1">
      <div class="text-xs text-n-slate-10">
        {{ label('CALL_STATUS', 'missed') }}
      </div>
      <div class="mt-1 text-2xl font-semibold text-n-slate-12">
        {{ counts.call_status?.missed || 0 }}
      </div>
    </div>
    <div class="p-4 border rounded-xl border-n-weak bg-n-solid-1">
      <div class="text-xs text-n-slate-10">
        {{ label('ACTION_STATUS', 'needs_follow_up') }}
      </div>
      <div class="mt-1 text-2xl font-semibold text-n-slate-12">
        {{ counts.action_status?.needs_follow_up || 0 }}
      </div>
    </div>
  </div>

  <div
    class="grid grid-cols-1 gap-3 p-4 mb-5 border rounded-xl border-n-weak bg-n-solid-1 sm:grid-cols-2 lg:grid-cols-3"
  >
    <label
      v-for="filter in [
        'call_status',
        'emotion',
        'status',
        'action_status',
        'purpose',
        'direction',
      ]"
      :key="filter"
      class="flex flex-col gap-1 text-xs text-n-slate-11"
    >
      {{ t(`PHONE_CALL_REPORTS.FILTERS.${filter.toUpperCase()}`) }}
      <select
        v-model="filters[filter]"
        class="h-9 px-2 border rounded-lg border-n-weak bg-n-alpha-2 text-n-slate-12"
      >
        <option value="">{{ t('PHONE_CALL_REPORTS.FILTERS.ALL') }}</option>
        <option
          v-for="value in options[
            filter === 'call_status'
              ? 'callStatus'
              : filter === 'action_status'
                ? 'actionStatus'
                : filter === 'status'
                  ? 'reportStatus'
                  : filter
          ]"
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
  </div>

  <div class="overflow-x-auto border rounded-xl border-n-weak bg-n-solid-1">
    <table class="w-full text-sm text-left">
      <thead
        class="text-xs border-b bg-n-alpha-2 border-n-weak text-n-slate-10"
      >
        <tr>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.TIME') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.CUSTOMER') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.DIRECTION') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.CALL_STATUS') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.EMOTION') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.PURPOSE') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.DURATION') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.ACTION_STATUS') }}</th>
          <th class="p-3">{{ t('PHONE_CALL_REPORTS.TABLE.CONVERSATION') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="isLoading">
          <td colspan="9" class="p-8 text-center text-n-slate-10">
            {{ t('PHONE_CALL_REPORTS.LOADING') }}
          </td>
        </tr>
        <tr v-else-if="!rows.length">
          <td colspan="9" class="p-8 text-center text-n-slate-10">
            {{ t('PHONE_CALL_REPORTS.EMPTY') }}
          </td>
        </tr>
        <template v-else>
          <tr
            v-for="row in rows"
            :key="row.phone_call_id"
            class="border-b last:border-0 border-n-weak text-n-slate-12"
          >
            <td class="p-3 whitespace-nowrap">
              {{ formatDate(row.started_at || row.created_at) }}
            </td>
            <td class="p-3 font-medium">{{ row.customer_number }}</td>
            <td class="p-3">{{ label('DIRECTION', row.direction) }}</td>
            <td class="p-3">{{ label('CALL_STATUS', row.call_status) }}</td>
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
            <td class="p-3">{{ label('PURPOSE', row.purpose) }}</td>
            <td class="p-3 tabular-nums">
              {{ formatDuration(row.duration_seconds) }}
            </td>
            <td class="p-3">
              <select
                v-if="row.id"
                :value="row.action_status"
                class="h-8 px-2 text-xs border rounded-lg border-n-weak bg-n-alpha-2"
                @change="updateActionStatus(row, $event.target.value)"
              >
                <option
                  v-for="value in options.actionStatus"
                  :key="value"
                  :value="value"
                >
                  {{ label('ACTION_STATUS', value) }}
                </option>
              </select>
              <span v-else>{{ t('PHONE_CALL_REPORTS.EMPTY_VALUE') }}</span>
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
      t('PHONE_CALL_REPORTS.PAGINATION', {
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
        {{ t('PHONE_CALL_REPORTS.PREVIOUS') }}
      </button>
      <button
        class="px-3 py-1.5 border rounded-lg border-n-weak disabled:opacity-40"
        :disabled="meta.current_page >= meta.total_pages"
        @click="changePage(meta.current_page + 1)"
      >
        {{ t('PHONE_CALL_REPORTS.NEXT') }}
      </button>
    </div>
  </div>
</template>
