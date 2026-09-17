<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import ContactAPI from 'dashboard/api/contacts';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  stages: { type: Array, required: true },
  agents: { type: Array, required: true },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['create']);

const { t } = useI18n();
const dialogRef = ref(null);
const contactOptions = ref([]);
const contactLabel = ref('');

const createInitialForm = () => ({
  name: '',
  value: '',
  stageId: props.stages[0]?.id || '',
  contactId: '',
  assigneeId: '',
  expectedCloseDate: '',
});

const form = reactive(createInitialForm());

const stageOptions = computed(() =>
  props.stages.map(stage => ({ value: stage.id, label: stage.name }))
);

const agentOptions = computed(() =>
  props.agents.map(agent => ({ value: agent.id, label: agent.name }))
);

const isFormInvalid = computed(() => !form.name.trim() || !form.stageId);

const searchContacts = debounce(async query => {
  const { data } = await ContactAPI.search(query);
  contactOptions.value = data.payload.map(contact => ({
    value: contact.id,
    label: contact.name,
  }));
}, 300);

const selectContact = contactId => {
  form.contactId = contactId;
  contactLabel.value =
    contactOptions.value.find(option => option.value === contactId)?.label ||
    '';
};

const open = ({ contactName = '', ...defaults } = {}) => {
  Object.assign(form, createInitialForm(), defaults);
  contactOptions.value = [];
  contactLabel.value = contactName;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (isFormInvalid.value) return;
  emit('create', {
    name: form.name.trim(),
    value: form.value === '' ? null : Number(form.value),
    stage_id: form.stageId,
    contact_id: form.contactId || null,
    assignee_id: form.assigneeId || null,
    expected_close_date: form.expectedCloseDate || null,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    :title="t('DEALS.FORM.CREATE_TITLE')"
    :confirm-button-label="t('DEALS.FORM.SAVE')"
    :disable-confirm-button="isFormInvalid"
    :is-loading="isLoading"
    overflow-y-auto
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="form.name"
        :placeholder="t('DEALS.FORM.NAME_PLACEHOLDER')"
        autofocus
      />
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Input
          v-model="form.value"
          type="number"
          min="0"
          :placeholder="t('DEALS.FORM.VALUE_PLACEHOLDER')"
        />
        <ComboBox
          v-model="form.stageId"
          :options="stageOptions"
          :placeholder="t('DEALS.FORM.STAGE_PLACEHOLDER')"
        />
        <ComboBox
          :model-value="form.contactId"
          :options="contactOptions"
          :display-label="contactLabel"
          :placeholder="t('DEALS.FORM.CONTACT_PLACEHOLDER')"
          :search-placeholder="t('DEALS.FORM.CONTACT_SEARCH_PLACEHOLDER')"
          use-api-results
          @search="searchContacts"
          @update:model-value="selectContact"
        />
        <ComboBox
          v-model="form.assigneeId"
          :options="agentOptions"
          :placeholder="t('DEALS.FORM.ASSIGNEE_PLACEHOLDER')"
        />
        <Input
          v-model="form.expectedCloseDate"
          type="date"
          :label="t('DEALS.FORM.EXPECTED_CLOSE_DATE')"
        />
      </div>
    </div>
  </Dialog>
</template>
