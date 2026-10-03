<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import TicketsAPI from 'dashboard/api/tickets';
import { useTicketsStore } from 'dashboard/stores/tickets';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { useSlaCountdown } from 'dashboard/components-next/Tickets/useSlaCountdown';
import { useTicketFields } from 'dashboard/components-next/Tickets/useTicketFields';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ContactAPI from 'dashboard/api/contacts';
import { debounce } from '@chatwoot/utils';
import { formatTicketDate } from 'dashboard/components-next/Tickets/constants';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const ticketsStore = useTicketsStore();
const pipelinesStore = useTicketPipelinesStore();
const agents = useMapGetter('agents/getAgents');
const { ticketAttributes } = useTicketFields();

const activities = ref([]);
const isFetching = ref(true);
const isSavingNote = ref(false);
const note = ref('');
const deleteDialogRef = ref(null);
const draftTitle = ref('');
const draftDescription = ref('');
const contactOptions = ref([]);

const TEXT_INPUT_TYPES = {
  number: 'number',
  currency: 'number',
  percent: 'number',
  date: 'date',
  link: 'url',
};

const inputTypeFor = attribute =>
  TEXT_INPUT_TYPES[attribute.attributeDisplayType] || 'text';

const listOptionsFor = attribute =>
  (attribute.attributeValues || []).map(value => ({ value, label: value }));

const ticketId = computed(() => Number(route.params.ticketId));
const ticket = computed(() => ticketsStore.watchedTicket);

const { hasSla, isOverdue, label, style } = useSlaCountdown(ticket);

const stages = computed(
  () => pipelinesStore.getPipeline(ticket.value?.pipelineId)?.stages || []
);

const stageOptions = computed(() =>
  stages.value.map(stage => ({ value: stage.id, label: stage.name }))
);

const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);

const currentStage = computed(() =>
  stages.value.find(stage => stage.id === ticket.value?.stageId)
);

const alertError = error => useAlert(error.message);

const save = changes => {
  ticketsStore.update(ticket.value, changes).catch(alertError);
};

const saveTitle = () => {
  const title = draftTitle.value.trim();
  if (!title || title === ticket.value.title) return;
  save({ title });
};

const saveDescription = () => {
  const description = draftDescription.value.trim();
  if (description === (ticket.value.description || '')) return;
  save({ description });
};

const moveToStage = async stageId => {
  if (!stageId || stageId === ticket.value.stageId) return;
  try {
    await ticketsStore.move(ticket.value, { stageId });
    await refreshActivities();
  } catch (error) {
    alertError(error);
  }
};

const assignTo = assigneeId => {
  if (assigneeId === ticket.value.assigneeId) return;
  save({ assigneeId: assigneeId || null });
};

const searchContacts = debounce(async query => {
  const { data } = await ContactAPI.search(query);
  contactOptions.value = data.payload.map(contact => ({
    value: contact.id,
    label: contact.name,
  }));
}, 300);

const assignContact = contactId => {
  if (contactId === ticket.value.contact?.id) return;
  save({ contactId: contactId || null });
};

const saveCustomAttribute = (key, value) => {
  save({
    customAttributes: { ...(ticket.value.customAttributes || {}), [key]: value },
  });
};

const refreshActivities = async () => {
  const { data } = await TicketsAPI.getActivities(ticketId.value);
  activities.value = data.payload;
};

const addNote = async () => {
  const content = note.value.trim();
  if (!content) return;
  isSavingNote.value = true;
  try {
    await TicketsAPI.addNote(ticketId.value, content);
    note.value = '';
    await refreshActivities();
  } catch (error) {
    alertError(error);
  } finally {
    isSavingNote.value = false;
  }
};

const deleteTicket = async () => {
  deleteDialogRef.value?.close();
  const { pipelineId } = ticket.value;
  try {
    await ticketsStore.delete(ticket.value);
    useAlert(t('TICKETS.MESSAGES.DELETE_SUCCESS'));
    router.push({
      name: 'tickets_pipeline_index',
      params: { pipelineId },
    });
  } catch {
    useAlert(t('TICKETS.MESSAGES.DELETE_ERROR'));
  }
};

const activityText = activity =>
  activity.action === 'note'
    ? activity.content
    : t(`TICKETS.ACTIVITY.ACTIONS.${activity.action.toUpperCase()}`);

const details = computed(() => {
  if (!ticket.value) return [];
  return [
    {
      key: 'created_by',
      label: t('TICKETS.FIELDS.CREATED_BY'),
      value: t(`TICKETS.CREATED_BY.${ticket.value.createdBy.toUpperCase()}`),
    },
    {
      key: 'created_at',
      label: t('TICKETS.FIELDS.CREATED_AT'),
      value: formatTicketDate(ticket.value.createdAt),
    },
  ];
});

onMounted(async () => {
  store.dispatch('agents/get');
  if (!pipelinesStore.records.length) {
    pipelinesStore.fetch().catch(alertError);
  }
  try {
    const record = await ticketsStore.show(ticketId.value);
    ticketsStore.watchTicket(record);
    draftTitle.value = record.title;
    draftDescription.value = record.description || '';
    await refreshActivities();
  } catch (error) {
    alertError(error);
  } finally {
    isFetching.value = false;
  }
});

onUnmounted(() => ticketsStore.unwatchTicket());
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div v-if="isFetching" class="flex justify-center py-16">
      <Spinner />
    </div>
    <div v-else-if="ticket" class="flex flex-col w-full max-w-3xl gap-6 px-6 py-6">
      <div class="flex items-start gap-3">
        <Button
          icon="i-lucide-arrow-left"
          color="slate"
          variant="ghost"
          size="sm"
          @click="router.back()"
        />
        <div class="flex flex-col flex-1 min-w-0 gap-2">
          <Input
            v-model="draftTitle"
            class="text-lg"
            @blur="saveTitle"
            @keyup.enter="saveTitle"
          />
          <span v-if="hasSla" class="flex items-center gap-1.5 text-sm">
            <Icon
              v-if="style"
              :icon="style.icon"
              class="size-4"
              :class="style.text"
            />
            <span :class="style?.text">
              {{
                isOverdue
                  ? t('TICKETS.SLA.OVERDUE_BY', { duration: label })
                  : t('TICKETS.SLA.DUE_IN', { duration: label })
              }}
            </span>
          </span>
        </div>
        <Button
          v-tooltip.top="t('TICKETS.DELETE')"
          icon="i-lucide-trash-2"
          color="ruby"
          variant="ghost"
          size="sm"
          @click="deleteDialogRef?.open()"
        />
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <span class="text-xs font-medium uppercase text-n-slate-11">
            {{ t('TICKETS.FIELDS.STAGE') }}
          </span>
          <ComboBox
            :model-value="ticket.stageId"
            :options="stageOptions"
            :placeholder="currentStage?.name"
            @update:model-value="moveToStage"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-xs font-medium uppercase text-n-slate-11">
            {{ t('TICKETS.FIELDS.ASSIGNEE') }}
          </span>
          <ComboBox
            :model-value="ticket.assignee?.id"
            :options="agentOptions"
            :placeholder="t('TICKETS.UNASSIGNED')"
            @update:model-value="assignTo"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-xs font-medium uppercase text-n-slate-11">
            {{ t('TICKETS.FIELDS.CONTACT') }}
          </span>
          <ComboBox
            :model-value="ticket.contact?.id"
            :options="contactOptions"
            :display-label="ticket.contact?.name"
            :placeholder="t('TICKETS.NO_CONTACT')"
            :search-placeholder="t('TICKETS.FORM.CONTACT_SEARCH_PLACEHOLDER')"
            use-api-results
            @search="searchContacts"
            @update:model-value="assignContact"
          />
        </div>
      </div>

      <div class="flex flex-col gap-1">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKETS.FIELDS.DESCRIPTION') }}
        </span>
        <TextArea
          v-model="draftDescription"
          :max-length="2000"
          min-height="6rem"
          auto-height
          :placeholder="t('TICKETS.FORM.DESCRIPTION_PLACEHOLDER')"
          @blur="saveDescription"
        />
      </div>

      <div v-if="ticketAttributes.length" class="flex flex-col gap-3">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKETS.FORM.CUSTOM_ATTRIBUTES') }}
        </span>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <template
            v-for="attribute in ticketAttributes"
            :key="attribute.attributeKey"
          >
            <label
              v-if="attribute.attributeDisplayType === 'checkbox'"
              class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
            >
              <Checkbox
                :model-value="
                  !!ticket.customAttributes?.[attribute.attributeKey]
                "
                @update:model-value="
                  saveCustomAttribute(attribute.attributeKey, $event)
                "
              />
              {{ attribute.attributeDisplayName }}
            </label>
            <Select
              v-else-if="attribute.attributeDisplayType === 'list'"
              :model-value="ticket.customAttributes?.[attribute.attributeKey]"
              :options="listOptionsFor(attribute)"
              :placeholder="attribute.attributeDisplayName"
              class="w-full"
              @update:model-value="
                saveCustomAttribute(attribute.attributeKey, $event)
              "
            />
            <Input
              v-else
              :model-value="ticket.customAttributes?.[attribute.attributeKey]"
              :type="inputTypeFor(attribute)"
              :label="attribute.attributeDisplayName"
              @blur="
                saveCustomAttribute(attribute.attributeKey, $event.target.value)
              "
            />
          </template>
        </div>
      </div>

      <dl class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div
          v-for="detail in details"
          :key="detail.key"
          class="flex flex-col gap-1"
        >
          <dt class="text-xs font-medium uppercase text-n-slate-11">
            {{ detail.label }}
          </dt>
          <dd class="flex items-center gap-2 mb-0 text-sm text-n-slate-12">
            <Avatar
              v-if="detail.avatar"
              :name="detail.avatar.name"
              :src="detail.avatar.thumbnail"
              :size="16"
              rounded-full
            />
            {{ detail.value }}
          </dd>
        </div>
      </dl>

      <div class="flex flex-col gap-3">
        <h2 class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKETS.ACTIVITY.TITLE') }}
        </h2>
        <div class="flex items-end gap-2">
          <TextArea
            v-model="note"
            class="flex-1"
            :max-length="1000"
            min-height="3rem"
            auto-height
            :placeholder="t('TICKETS.ACTIVITY.NOTE_PLACEHOLDER')"
          />
          <Button
            :label="t('TICKETS.ACTIVITY.ADD_NOTE')"
            size="sm"
            :disabled="!note.trim()"
            :is-loading="isSavingNote"
            @click="addNote"
          />
        </div>
        <ul class="flex flex-col gap-2">
          <li
            v-for="activity in activities"
            :key="activity.id"
            class="flex items-start gap-2 text-sm text-n-slate-11"
          >
            <span class="flex-shrink-0 text-n-slate-12">
              {{ activity.actor?.name || t('TICKETS.ACTIVITY.SYSTEM') }}
            </span>
            <span class="flex-1 whitespace-pre-line">
              {{ activityText(activity) }}
            </span>
            <span class="flex-shrink-0">
              {{ formatTicketDate(activity.created_at) }}
            </span>
          </li>
        </ul>
      </div>
      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="t('TICKETS.DELETE_CONFIRM.TITLE')"
        :description="
          t('TICKETS.DELETE_CONFIRM.DESCRIPTION', { title: ticket.title })
        "
        :confirm-button-label="t('TICKETS.DELETE_CONFIRM.CONFIRM')"
        @confirm="deleteTicket"
      />
    </div>
  </section>
</template>
