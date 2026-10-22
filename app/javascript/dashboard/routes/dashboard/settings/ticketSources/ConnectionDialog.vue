<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  providers: { type: Array, required: true },
  pipelines: { type: Array, required: true },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const dialogRef = ref(null);
const editing = ref(null);
const provider = ref('');
const name = ref('');
const pipelineId = ref('');
const credentials = ref({});
const settings = ref({});

const providerConfig = computed(() =>
  props.providers.find(item => item.provider === provider.value)
);
const providerOptions = computed(() =>
  props.providers.map(item => ({ value: item.provider, label: item.provider }))
);
const pipelineOptions = computed(() => [
  { value: '', label: t('TICKET_SOURCES_SETTINGS.FORM.NEW_PIPELINE') },
  ...props.pipelines.map(item => ({ value: item.id, label: item.name })),
]);
const canSubmit = computed(
  () =>
    name.value.trim() &&
    providerConfig.value?.setting_fields
      .filter(field => field.required)
      .every(field => settings.value[field.key])
);

const open = connection => {
  editing.value = connection;
  provider.value = connection?.provider || props.providers[0]?.provider || '';
  name.value = connection?.name || '';
  pipelineId.value = connection?.pipeline_id || '';
  credentials.value = { ...(connection?.credentials || {}) };
  settings.value = { ...(connection?.settings || {}) };
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const submit = () => {
  emit('submit', {
    id: editing.value?.id,
    payload: {
      provider: provider.value,
      name: name.value.trim(),
      pipeline_id: pipelineId.value || undefined,
      credentials: credentials.value,
      settings: settings.value,
    },
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      editing
        ? t('TICKET_SOURCES_SETTINGS.FORM.EDIT_TITLE')
        : t('TICKET_SOURCES_SETTINGS.FORM.CREATE_TITLE')
    "
    :confirm-button-label="t('TICKET_SOURCES_SETTINGS.FORM.SAVE')"
    :disable-confirm-button="!canSubmit"
    :is-loading="isSaving"
    overflow-y-auto
    @confirm="submit"
  >
    <div v-if="providerConfig" class="flex flex-col gap-4">
      <Select
        v-model="provider"
        :options="providerOptions"
        :disabled="!!editing"
        :label="t('TICKET_SOURCES_SETTINGS.FORM.PROVIDER')"
      />
      <Input
        v-model="name"
        :label="t('TICKET_SOURCES_SETTINGS.FORM.NAME')"
        :placeholder="t('TICKET_SOURCES_SETTINGS.FORM.NAME_PLACEHOLDER')"
      />
      <Select
        v-model="pipelineId"
        :options="pipelineOptions"
        :disabled="!!editing"
        :label="t('TICKET_SOURCES_SETTINGS.FORM.PIPELINE')"
      />
      <Input
        v-for="field in providerConfig.credential_fields"
        :key="field.key"
        v-model="credentials[field.key]"
        :label="field.label"
        :type="field.secret ? 'password' : 'text'"
        :placeholder="
          field.secret && editing
            ? t('TICKET_SOURCES_SETTINGS.FORM.SECRET_UNCHANGED')
            : ''
        "
      />
      <template v-for="field in providerConfig.setting_fields" :key="field.key">
        <label
          v-if="field.type === 'boolean'"
          class="flex items-center gap-2 text-sm text-n-slate-12"
        >
          <Checkbox v-model="settings[field.key]" />
          {{ field.label }}
        </label>
        <Input v-else v-model="settings[field.key]" :label="field.label" />
      </template>
    </div>
  </Dialog>
</template>
