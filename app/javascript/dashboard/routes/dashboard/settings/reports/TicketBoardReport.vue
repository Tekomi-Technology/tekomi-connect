<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { formatTicketDate } from 'dashboard/components-next/Tickets/constants';
import TicketReportsAPI from 'dashboard/api/ticketReports';
import ReportHeader from './components/ReportHeader.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const SLA_CHIP_CLASSES = {
  on_track: 'bg-n-teal-3 text-n-teal-11',
  at_risk: 'bg-n-amber-3 text-n-amber-11',
  breached: 'bg-n-ruby-3 text-n-ruby-11',
  no_sla: 'bg-n-alpha-2 text-n-slate-11',
};

const { t } = useI18n();
const router = useRouter();

const isFetching = ref(true);
const board = ref({ pipelines: [], pipeline: null, stages: [] });
const pipelineId = ref(null);

const pipelineOptions = computed(() =>
  board.value.pipelines.map(pipeline => ({
    value: pipeline.id,
    label: `${pipeline.name} (${pipeline.ticketsCount})`,
  }))
);
const source = computed(() => board.value.pipeline?.source);

const fetchBoard = async () => {
  isFetching.value = true;
  try {
    const { data } = await TicketReportsAPI.board(pipelineId.value);
    board.value = camelcaseKeys(data, { deep: true });
    pipelineId.value = board.value.pipeline?.id ?? null;
  } catch (error) {
    useAlert(error.message);
  } finally {
    isFetching.value = false;
  }
};

const openTicket = ticket =>
  router.push(
    frontendURL(
      `accounts/${router.currentRoute.value.params.accountId}/tickets/${ticket.id}`
    )
  );

watch(pipelineId, (next, previous) => {
  if (previous !== null && next !== board.value.pipeline?.id) fetchBoard();
});

onMounted(fetchBoard);
</script>

<template>
  <section class="flex flex-col w-full h-full gap-4 overflow-hidden">
    <ReportHeader
      :header-title="t('TICKET_BOARD_REPORT.HEADER')"
      :header-description="t('TICKET_BOARD_REPORT.DESCRIPTION')"
    />

    <div v-if="isFetching && !board.pipeline" class="flex justify-center p-12">
      <Spinner />
    </div>
    <p
      v-else-if="!board.pipeline"
      class="p-12 text-sm text-center text-n-slate-11"
    >
      {{ t('TICKET_BOARD_REPORT.EMPTY') }}
    </p>
    <template v-else>
      <div class="flex flex-wrap items-center gap-4">
        <div class="flex flex-col gap-1 w-72">
          <span class="text-xs font-medium uppercase text-n-slate-11">
            {{ t('TICKET_BOARD_REPORT.PIPELINE') }}
          </span>
          <ComboBox v-model="pipelineId" :options="pipelineOptions" />
        </div>
        <p v-if="source" class="text-sm text-n-slate-11">
          {{
            t('TICKET_BOARD_REPORT.SOURCE', {
              name: source.name,
              provider: source.provider,
            })
          }}
          ·
          {{
            source.lastSyncedAt
              ? t('TICKET_BOARD_REPORT.LAST_SYNCED', {
                  time: formatTicketDate(source.lastSyncedAt),
                })
              : t('TICKET_BOARD_REPORT.NEVER_SYNCED')
          }}
        </p>
        <Spinner v-if="isFetching" class="size-4" />
      </div>
      <p v-if="source?.lastError" class="text-sm text-n-ruby-11">
        {{ source.lastError }}
      </p>

      <div class="flex flex-1 gap-4 pb-4 overflow-x-auto">
        <div
          v-for="stage in board.stages"
          :key="stage.id"
          class="flex flex-col flex-shrink-0 gap-3 p-3 rounded-xl w-72 bg-n-alpha-1 min-h-0"
        >
          <div class="flex items-center gap-2">
            <span
              class="rounded-full size-2.5"
              :style="{ backgroundColor: stage.color }"
            />
            <span class="flex-1 text-sm font-medium truncate text-n-slate-12">
              {{ stage.name }}
            </span>
            <span class="text-xs text-n-slate-11">{{ stage.count }}</span>
          </div>
          <div class="flex flex-col gap-2 overflow-y-auto">
            <p
              v-if="!stage.tickets.length"
              class="py-4 text-xs text-center text-n-slate-10"
            >
              {{ t('TICKET_BOARD_REPORT.EMPTY_COLUMN') }}
            </p>
            <button
              v-for="ticket in stage.tickets"
              :key="ticket.id"
              type="button"
              class="flex flex-col gap-2 p-3 text-sm border rounded-lg shadow-sm text-start border-n-weak bg-n-solid-2 hover:border-n-slate-6"
              @click="openTicket(ticket)"
            >
              <span class="font-medium text-n-slate-12 line-clamp-2">
                {{ ticket.title }}
              </span>
              <div class="flex flex-wrap items-center gap-2">
                <a
                  v-if="ticket.external"
                  :href="ticket.external.url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="flex items-center gap-1 px-1.5 py-0.5 text-xs rounded-md bg-n-blue-3 text-n-blue-11"
                  @click.stop
                >
                  <Icon icon="i-lucide-external-link" class="size-3" />
                  {{ ticket.external.key }}
                </a>
                <span
                  class="px-1.5 py-0.5 text-xs rounded-md"
                  :class="SLA_CHIP_CLASSES[ticket.slaStatus]"
                >
                  {{ t(`TICKET_BOARD_REPORT.SLA.${ticket.slaStatus}`) }}
                </span>
              </div>
              <div
                class="flex items-center justify-between gap-2 text-xs text-n-slate-11"
              >
                <span class="flex items-center min-w-0 gap-1">
                  <Icon
                    icon="i-lucide-user-round"
                    class="flex-shrink-0 size-3"
                  />
                  <span class="truncate">
                    {{ ticket.assignee || t('TICKET_BOARD_REPORT.UNASSIGNED') }}
                  </span>
                </span>
                <span class="flex-shrink-0">
                  {{ formatTicketDate(ticket.updatedAt) }}
                </span>
              </div>
            </button>
            <p
              v-if="stage.count > stage.tickets.length"
              class="py-1 text-xs text-center text-n-slate-10"
            >
              {{
                t('TICKET_BOARD_REPORT.MORE', {
                  count: stage.count - stage.tickets.length,
                })
              }}
            </p>
          </div>
        </div>
      </div>
    </template>
  </section>
</template>
