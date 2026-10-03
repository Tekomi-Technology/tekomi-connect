<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import TicketsAPI from 'dashboard/api/tickets';
import { camelizeTicket } from 'dashboard/stores/tickets';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketSummaryRow from './TicketSummaryRow.vue';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const router = useRouter();
const pipelinesStore = useTicketPipelinesStore();

const tickets = ref([]);
const isLoading = ref(false);

const stagesById = computed(() =>
  Object.fromEntries(
    pipelinesStore.records.flatMap(pipeline =>
      pipeline.stages.map(stage => [stage.id, stage])
    )
  )
);

const loadTickets = async () => {
  isLoading.value = true;
  try {
    const { data } = await TicketsAPI.getByContact(props.contactId);
    tickets.value = data.payload.map(camelizeTicket);
  } catch {
    useAlert(t('TICKETS.CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const openTicket = ticket => {
  router.push({ name: 'tickets_show', params: { ticketId: ticket.id } });
};

watch(() => props.contactId, loadTickets);

onMounted(() => {
  loadTickets();
  if (!pipelinesStore.records.length) pipelinesStore.fetch();
});
</script>

<template>
  <div class="flex flex-col gap-2 px-2 pb-2">
    <div v-if="isLoading" class="flex justify-center py-3">
      <Spinner :size="20" />
    </div>
    <template v-else>
      <p v-if="!tickets.length" class="mb-0 text-sm text-n-slate-11">
        {{ t('TICKETS.CONTACT.EMPTY') }}
      </p>
      <TicketSummaryRow
        v-for="ticket in tickets"
        :key="ticket.id"
        :ticket="ticket"
        :stage="stagesById[ticket.stageId]"
        @open="openTicket(ticket)"
      />
    </template>
  </div>
</template>
