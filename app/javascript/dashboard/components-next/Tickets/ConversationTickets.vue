<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import CrmTicketsAPI from 'dashboard/api/crmTickets';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// Tickets live in the external CRM. This panel lists the ones sent from this
// conversation, newest first, and is read-only: sending happens from the
// "Send conversation transcript" dialog.
const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const emit = defineEmits(['loaded']);

const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');

const tickets = ref([]);
const isLoading = ref(false);

// The delivery job writes the ticket reference onto the conversation after the
// CRM replies, so the panel follows that value instead of a one-off event.
const ticketRefs = computed(() => {
  const attributes = currentChat.value?.custom_attributes || {};
  return JSON.stringify(
    attributes.crm_tickets || attributes.crm_ticket || null
  );
});

const loadTickets = async () => {
  isLoading.value = true;
  try {
    const { data } = await CrmTicketsAPI.getByConversation(
      props.conversationId
    );
    tickets.value = data.payload || [];
    emit('loaded', tickets.value.length);
  } catch {
    useAlert(t('TICKETS.CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch([() => props.conversationId, ticketRefs], loadTickets, {
  immediate: true,
});
</script>

<template>
  <div class="flex flex-col gap-3 px-2 pb-2">
    <div v-if="isLoading" class="flex justify-center py-3">
      <Spinner :size="20" />
    </div>
    <p v-else-if="!tickets.length" class="mb-0 text-sm text-n-slate-11">
      {{ t('TICKETS.CONVERSATION.EMPTY') }}
    </p>
    <div v-else class="flex flex-col gap-2">
      <div
        v-for="ticket in tickets"
        :key="ticket.ticketid"
        class="flex flex-col gap-1 p-2 text-sm rounded-lg bg-n-alpha-1"
      >
        <span class="font-medium truncate text-n-slate-12">
          {{ ticket.subject }}
        </span>
        <span class="flex items-center gap-1.5 text-xs text-n-slate-11">
          #{{ ticket.ticketid }}
          <template v-if="ticket.date">· {{ ticket.date }}</template>
        </span>
      </div>
    </div>
  </div>
</template>
