<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import TicketsAPI from 'dashboard/api/tickets';
import { camelizeTicket, useTicketsStore } from 'dashboard/stores/tickets';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketFormDialog from './TicketFormDialog.vue';
import TicketSummaryRow from './TicketSummaryRow.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  contact: { type: Object, default: null },
});

const emit = defineEmits(['loaded']);

const { t } = useI18n();
const router = useRouter();
const ticketsStore = useTicketsStore();
const pipelinesStore = useTicketPipelinesStore();
const agents = useMapGetter('agents/getAgents');
const accountId = useMapGetter('getCurrentAccountId');
const currentChat = useMapGetter('getSelectedChat');

const linkedTickets = ref([]);
const contactTickets = ref([]);
const isLoading = ref(false);
const isCreating = ref(false);
const formDialogRef = ref(null);
let reloadTimer = null;

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
const otherContactTickets = computed(() => {
  const linkedIds = linkedTickets.value.map(ticket => ticket.id);
  return contactTickets.value.filter(ticket => !linkedIds.includes(ticket.id));
});
const sections = computed(() => [
  { key: 'linked', tickets: linkedTickets.value, linked: true },
  { key: 'contact', tickets: otherContactTickets.value, linked: false },
]);

const conversationUrl = computed(
  () =>
    `${window.location.origin}/app/accounts/${accountId.value}/conversations/${props.conversationId}`
);

const loadTickets = async ({ silent = false } = {}) => {
  if (!silent) isLoading.value = true;
  try {
    const [linkedResponse, contactResponse] = await Promise.all([
      TicketsAPI.getByConversation(props.conversationId),
      props.contact?.id ? TicketsAPI.getByContact(props.contact.id) : null,
    ]);
    linkedTickets.value = linkedResponse.data.payload.map(camelizeTicket);
    contactTickets.value =
      contactResponse?.data.payload.map(camelizeTicket) || [];
    emit('loaded', linkedTickets.value.length + contactTickets.value.length);
  } catch {
    useAlert(t('TICKETS.CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const linkTicket = async ticket => {
  try {
    await TicketsAPI.linkConversation(ticket.id, props.conversationId);
    await loadTickets({ silent: true });
  } catch {
    useAlert(t('TICKETS.CONVERSATION.LINK_ERROR'));
  }
};

const unlinkTicket = async ticket => {
  try {
    await TicketsAPI.unlinkConversation(ticket.id, props.conversationId);
    await loadTickets({ silent: true });
  } catch {
    useAlert(t('TICKETS.CONVERSATION.UNLINK_ERROR'));
  }
};

const openTicket = ticket => {
  router.push({ name: 'tickets_show', params: { ticketId: ticket.id } });
};

const openCreateTicket = () => {
  const name = props.contact?.name || currentChat.value?.meta?.sender?.name;
  formDialogRef.value?.open({
    contactId: props.contact?.id || '',
    contactName: props.contact?.name || '',
    title: name
      ? t('TICKETS.CONVERSATION.DEFAULT_TITLE', {
          name,
          id: props.conversationId,
        })
      : '',
    description: t('TICKETS.CONVERSATION.DEFAULT_DESCRIPTION', {
      id: props.conversationId,
      url: conversationUrl.value,
    }),
  });
};

const createTicket = async ticket => {
  isCreating.value = true;
  try {
    await TicketsAPI.createFromConversation(ticket, props.conversationId);
    formDialogRef.value?.close();
    useAlert(t('TICKETS.FORM.MESSAGES.SUCCESS'));
    await loadTickets({ silent: true });
  } catch {
    useAlert(t('TICKETS.FORM.MESSAGES.ERROR'));
  } finally {
    isCreating.value = false;
  }
};

// Tickets also change on their own (an external source moves them), so the panel follows the realtime feed.
watch(
  () => ticketsStore.realtimeVersion,
  () => {
    clearTimeout(reloadTimer);
    reloadTimer = setTimeout(() => loadTickets({ silent: true }), 500);
  }
);
watch(() => [props.conversationId, props.contact?.id], loadTickets);

onMounted(() => {
  loadTickets();
  if (!pipelinesStore.records.length) pipelinesStore.fetch();
});
onBeforeUnmount(() => clearTimeout(reloadTimer));
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
      <template v-for="section in sections" :key="section.key">
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
            <a
              v-if="ticket.external"
              v-tooltip.top="ticket.external.provider"
              :href="ticket.external.url"
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center flex-shrink-0 gap-1 px-1.5 py-0.5 text-xs rounded-md bg-n-blue-3 text-n-blue-11"
            >
              <Icon icon="i-lucide-external-link" class="size-3" />
              {{ ticket.external.key }}
            </a>
            <Button
              :icon="section.linked ? 'i-lucide-unlink' : 'i-lucide-link'"
              color="slate"
              variant="ghost"
              size="xs"
              @click="
                section.linked ? unlinkTicket(ticket) : linkTicket(ticket)
              "
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
      ref="formDialogRef"
      :stages="stages"
      :agents="agents"
      :is-loading="isCreating"
      @create="createTicket"
    />
  </div>
</template>
