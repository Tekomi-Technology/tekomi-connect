<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import TicketsAPI from 'dashboard/api/tickets';
import { camelizeTicket, useTicketsStore } from 'dashboard/stores/tickets';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketFormDialog from './TicketFormDialog.vue';
import TicketSummaryRow from './TicketSummaryRow.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contact: { type: Object, default: null },
});

const { t } = useI18n();
const router = useRouter();
const ticketsStore = useTicketsStore();
const pipelinesStore = useTicketPipelinesStore();
const agents = useMapGetter('agents/getAgents');

const linkedTickets = ref([]);
const contactTickets = ref([]);
const isLoading = ref(false);
const ticketFormDialogRef = ref(null);

const stages = computed(() =>
  pipelinesStore.records.flatMap(pipeline =>
    pipeline.stages.map(stage => ({
      ...stage,
      name:
        pipelinesStore.records.length > 1
          ? `${pipeline.name} · ${stage.name}`
          : stage.name,
    }))
  )
);
const stagesById = computed(() =>
  Object.fromEntries(stages.value.map(stage => [stage.id, stage]))
);

// Tickets the contact already has that are not tied to this conversation yet.
const otherContactTickets = computed(() => {
  const linkedIds = linkedTickets.value.map(ticket => ticket.id);
  return contactTickets.value.filter(ticket => !linkedIds.includes(ticket.id));
});

const loadTickets = async () => {
  isLoading.value = true;
  try {
    const [linkedResponse, contactResponse] = await Promise.all([
      TicketsAPI.getByConversation(props.conversationId),
      props.contact?.id ? TicketsAPI.getByContact(props.contact.id) : null,
    ]);
    linkedTickets.value = linkedResponse.data.payload.map(camelizeTicket);
    contactTickets.value =
      contactResponse?.data.payload.map(camelizeTicket) || [];
  } catch {
    useAlert(t('TICKETS.CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const linkTicket = async ticket => {
  try {
    await TicketsAPI.linkConversation(ticket.id, props.conversationId);
    await loadTickets();
  } catch {
    useAlert(t('TICKETS.CONVERSATION.LINK_ERROR'));
  }
};

const unlinkTicket = async ticket => {
  try {
    await TicketsAPI.unlinkConversation(ticket.id, props.conversationId);
    await loadTickets();
  } catch {
    useAlert(t('TICKETS.CONVERSATION.UNLINK_ERROR'));
  }
};

const openTicket = ticket => {
  router.push({ name: 'tickets_show', params: { ticketId: ticket.id } });
};

const openCreateTicket = () => {
  ticketFormDialogRef.value?.open({
    contactId: props.contact?.id || '',
    contactName: props.contact?.name || '',
  });
};

const createTicket = async payload => {
  try {
    const ticket = await ticketsStore.create(payload);
    await TicketsAPI.linkConversation(ticket.id, props.conversationId);
    ticketFormDialogRef.value?.close();
    useAlert(t('TICKETS.FORM.MESSAGES.SUCCESS'));
    await loadTickets();
  } catch {
    useAlert(t('TICKETS.FORM.MESSAGES.ERROR'));
  }
};

watch(() => [props.conversationId, props.contact?.id], loadTickets);

onMounted(() => {
  loadTickets();
  if (!pipelinesStore.records.length) pipelinesStore.fetch();
});
</script>

<template>
  <div class="flex flex-col gap-3 px-2 pb-2">
    <div v-if="isLoading" class="flex justify-center py-3">
      <Spinner :size="20" />
    </div>
    <template v-else>
      <p
        v-if="!linkedTickets.length && !otherContactTickets.length"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('TICKETS.CONVERSATION.EMPTY') }}
      </p>
      <template
        v-for="section in [
          { key: 'linked', tickets: linkedTickets, linked: true },
          { key: 'contact', tickets: otherContactTickets, linked: false },
        ]"
        :key="section.key"
      >
        <div v-if="section.tickets.length" class="flex flex-col gap-2">
          <span class="text-xs font-medium uppercase text-n-slate-11">
            {{ t(`TICKETS.CONVERSATION.${section.key.toUpperCase()}`) }}
          </span>
          <TicketSummaryRow
            v-for="ticket in section.tickets"
            :key="ticket.id"
            :ticket="ticket"
            :stage="stagesById[ticket.stageId]"
            @open="openTicket(ticket)"
          >
            <Button
              :icon="section.linked ? 'i-lucide-unlink' : 'i-lucide-link'"
              color="slate"
              variant="ghost"
              size="xs"
              @click="section.linked ? unlinkTicket(ticket) : linkTicket(ticket)"
            />
          </TicketSummaryRow>
        </div>
      </template>
    </template>
    <Button
      :label="t('TICKETS.CONVERSATION.CREATE')"
      icon="i-lucide-plus"
      color="slate"
      variant="faded"
      size="sm"
      @click="openCreateTicket"
    />
    <TicketFormDialog
      ref="ticketFormDialogRef"
      :stages="stages"
      :agents="agents"
      :is-loading="ticketsStore.uiFlags.isCreating"
      @create="createTicket"
    />
  </div>
</template>
