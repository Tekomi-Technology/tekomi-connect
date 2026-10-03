<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { format, subDays } from 'date-fns';
import { useAlert } from 'dashboard/composables';
import TicketReportsAPI from 'dashboard/api/ticketReports';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import ReportHeader from './components/ReportHeader.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const { t } = useI18n();
const pipelinesStore = useTicketPipelinesStore();

const isFetching = ref(true);
const report = ref(null);
const pipelineId = ref(null);
const since = ref(format(subDays(new Date(), 29), 'yyyy-MM-dd'));
const until = ref(format(new Date(), 'yyyy-MM-dd'));

const pipelineOptions = computed(() => [
  { value: null, label: t('TICKET_REPORTS.ALL_PIPELINES') },
  ...pipelinesStore.records.map(pipeline => ({
    value: pipeline.id,
    label: pipeline.name,
  })),
]);

const formatDuration = seconds => {
  if (seconds === null || seconds === undefined) return '—';
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours >= 24) return `${Math.floor(hours / 24)}d ${hours % 24}h`;
  return hours ? `${hours}h ${minutes}m` : `${minutes}m`;
};

const fetchReport = async () => {
  isFetching.value = true;
  try {
    const { data } = await TicketReportsAPI.get({
      since: since.value,
      until: until.value,
      pipelineId: pipelineId.value,
    });
    report.value = data;
  } catch (error) {
    useAlert(error.message);
  } finally {
    isFetching.value = false;
  }
};

watch([since, until, pipelineId], fetchReport);

onMounted(() => {
  pipelinesStore.fetch().catch(error => useAlert(error.message));
  fetchReport();
});
</script>

<template>
  <section class="flex flex-col w-full h-full gap-6 overflow-y-auto">
    <ReportHeader
      :header-title="t('TICKET_REPORTS.HEADER')"
      :header-description="t('TICKET_REPORTS.DESCRIPTION')"
    />

    <div class="flex flex-wrap items-end gap-3">
      <div class="flex flex-col gap-1">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKET_REPORTS.FROM') }}
        </span>
        <Input v-model="since" type="date" />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKET_REPORTS.TO') }}
        </span>
        <Input v-model="until" type="date" />
      </div>
      <div class="flex flex-col gap-1 min-w-48">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKET_REPORTS.PIPELINE') }}
        </span>
        <ComboBox v-model="pipelineId" :options="pipelineOptions" />
      </div>
    </div>

    <div v-if="isFetching" class="flex justify-center py-16">
      <Spinner />
    </div>

    <template v-else-if="report">
      <section class="flex flex-col gap-3">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('TICKET_REPORTS.STAGE_PERFORMANCE.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('TICKET_REPORTS.STAGE_PERFORMANCE.HINT') }}
        </p>
        <BaseTable
          :headers="[
            t('TICKETS.FIELDS.STAGE'),
            t('TICKET_REPORTS.STAGE_PERFORMANCE.TOTAL'),
            t('TICKET_REPORTS.STAGE_PERFORMANCE.MISSED'),
            t('TICKET_REPORTS.STAGE_PERFORMANCE.ON_TIME_RATE'),
            t('TICKET_REPORTS.STAGE_PERFORMANCE.AVG_TIME'),
          ]"
          :items="report.stage_performance"
          :no-data-message="t('TICKET_REPORTS.EMPTY')"
        >
          <template #row="{ items }">
            <BaseTableRow v-for="row in items" :key="row.stage_id" :item="row">
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12">
                    {{ row.stage_name }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-28">{{ row.total }}</BaseTableCell>
                <BaseTableCell class="w-28">
                  <span :class="row.missed ? 'text-n-ruby-11' : ''">
                    {{ row.missed }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-32">
                  {{ row.on_time_rate }}%
                </BaseTableCell>
                <BaseTableCell class="w-32">
                  {{ formatDuration(row.avg_seconds) }}
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </section>

      <section class="flex flex-col gap-3">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('TICKET_REPORTS.WORKLOAD.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('TICKET_REPORTS.WORKLOAD.HINT') }}
        </p>
        <BaseTable
          :headers="[
            t('TICKETS.FIELDS.STAGE'),
            t('TICKET_REPORTS.WORKLOAD.OPEN'),
            t('TICKETS.SLA_STATUS.AT_RISK'),
            t('TICKETS.SLA_STATUS.BREACHED'),
          ]"
          :items="report.workload"
          :no-data-message="t('TICKET_REPORTS.EMPTY')"
        >
          <template #row="{ items }">
            <BaseTableRow v-for="row in items" :key="row.stage_id" :item="row">
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12">
                    {{ row.stage_name }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-28">{{ row.open }}</BaseTableCell>
                <BaseTableCell class="w-28">
                  <span :class="row.at_risk ? 'text-n-amber-11' : ''">
                    {{ row.at_risk }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-28">
                  <span :class="row.breached ? 'text-n-ruby-11' : ''">
                    {{ row.breached }}
                  </span>
                </BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </section>

      <section class="flex flex-col gap-3 pb-6">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('TICKET_REPORTS.SOURCES.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('TICKET_REPORTS.SOURCES.HINT') }}
        </p>
        <BaseTable
          :headers="[
            t('TICKET_REPORTS.SOURCES.SOURCE'),
            t('TICKET_REPORTS.SOURCES.COUNT'),
            t('TICKET_REPORTS.SOURCES.SHARE'),
          ]"
          :items="report.sources"
          :no-data-message="t('TICKET_REPORTS.EMPTY')"
        >
          <template #row="{ items }">
            <BaseTableRow v-for="row in items" :key="row.source" :item="row">
              <template #default>
                <BaseTableCell>
                  <span class="text-body-main text-n-slate-12">
                    {{ t(`TICKETS.CREATED_BY.${row.source.toUpperCase()}`) }}
                  </span>
                </BaseTableCell>
                <BaseTableCell class="w-28">{{ row.count }}</BaseTableCell>
                <BaseTableCell class="w-28">{{ row.share }}%</BaseTableCell>
              </template>
            </BaseTableRow>
          </template>
        </BaseTable>
      </section>
    </template>
  </section>
</template>
