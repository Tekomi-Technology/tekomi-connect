<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { useTicketWebhooksStore } from 'dashboard/stores/ticketWebhooks';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const { t } = useI18n();
const webhooksStore = useTicketWebhooksStore();
const pipelinesStore = useTicketPipelinesStore();

const createDialogRef = ref(null);
const tokenDialogRef = ref(null);
const deleteDialogRef = ref(null);
const form = ref({ name: '', pipelineId: null });
const createdWebhook = ref(null);
const pendingDelete = ref(null);

const pipelineOptions = computed(() =>
  pipelinesStore.records.map(pipeline => ({
    value: pipeline.id,
    label: pipeline.name,
  }))
);

const pipelineName = pipelineId =>
  pipelinesStore.records.find(pipeline => pipeline.id === pipelineId)?.name ||
  '';

const fullUrl = webhook => `${window.location.origin}${webhook.endpointPath}`;

const isFormInvalid = computed(
  () => !form.value.name.trim() || !form.value.pipelineId
);

const alertError = error => useAlert(error.message);

const openCreate = () => {
  form.value = {
    name: '',
    pipelineId: pipelineOptions.value[0]?.value || null,
  };
  createDialogRef.value?.open();
};

const createWebhook = async () => {
  if (isFormInvalid.value) return;
  try {
    createdWebhook.value = await webhooksStore.create({
      name: form.value.name.trim(),
      pipelineId: form.value.pipelineId,
    });
    createDialogRef.value?.close();
    tokenDialogRef.value?.open();
  } catch (error) {
    alertError(error);
  }
};

const copyUrl = async webhook => {
  await copyTextToClipboard(fullUrl(webhook));
  useAlert(t('WEBHOOK.MESSAGES.COPIED'));
};

const openDelete = webhook => {
  pendingDelete.value = webhook;
  deleteDialogRef.value?.open();
};

const deleteWebhook = async () => {
  deleteDialogRef.value?.close();
  try {
    await webhooksStore.delete(pendingDelete.value.id);
    useAlert(t('WEBHOOK.MESSAGES.DELETE_SUCCESS'));
  } catch (error) {
    alertError(error);
  }
};

onMounted(() => {
  webhooksStore.fetch().catch(alertError);
  pipelinesStore.fetch().catch(alertError);
});
</script>

<template>
  <SettingsLayout
    :is-loading="webhooksStore.uiFlags.isFetching"
    :loading-message="t('WEBHOOK.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('WEBHOOK.HEADER')"
        :description="t('WEBHOOK.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('WEBHOOK.ADD')"
            icon="i-lucide-plus"
            size="sm"
            :disabled="!pipelineOptions.length"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <p
        v-if="!webhooksStore.records.length"
        class="py-16 text-base text-center text-n-slate-11"
      >
        {{ t('WEBHOOK.EMPTY') }}
      </p>
      <div v-else class="border rounded-xl border-n-weak bg-n-solid-1">
        <div
          v-for="webhook in webhooksStore.records"
          :key="webhook.id"
          class="flex items-center gap-3 px-4 py-3 border-b border-n-weak last:border-b-0"
        >
          <div class="flex flex-col min-w-0 gap-1">
            <span class="font-medium truncate text-n-slate-12">
              {{ webhook.name }}
            </span>
            <span class="text-sm truncate text-n-slate-11">
              {{ pipelineName(webhook.pipelineId) }} · {{ fullUrl(webhook) }}
            </span>
          </div>
          <div class="flex gap-1 ltr:ml-auto rtl:mr-auto">
            <Button
              v-tooltip.top="t('WEBHOOK.COPY_URL')"
              icon="i-lucide-copy"
              color="slate"
              variant="ghost"
              size="sm"
              @click="copyUrl(webhook)"
            />
            <Button
              v-tooltip.top="t('WEBHOOK.DELETE')"
              icon="i-lucide-trash-2"
              color="ruby"
              variant="ghost"
              size="sm"
              @click="openDelete(webhook)"
            />
          </div>
        </div>
      </div>

      <Dialog
        ref="createDialogRef"
        :title="t('WEBHOOK.FORM.TITLE')"
        :confirm-button-label="t('WEBHOOK.FORM.SAVE')"
        :disable-confirm-button="isFormInvalid"
        :is-loading="webhooksStore.uiFlags.isCreating"
        @confirm="createWebhook"
      >
        <div class="flex flex-col gap-4">
          <Input
            v-model="form.name"
            :label="t('WEBHOOK.FORM.NAME')"
            :placeholder="t('WEBHOOK.FORM.NAME_PLACEHOLDER')"
            autofocus
          />
          <div class="flex flex-col gap-1">
            <span class="text-xs font-medium uppercase text-n-slate-11">
              {{ t('WEBHOOK.FORM.PIPELINE') }}
            </span>
            <ComboBox
              v-model="form.pipelineId"
              :options="pipelineOptions"
              :placeholder="t('WEBHOOK.FORM.PIPELINE')"
            />
          </div>
        </div>
      </Dialog>

      <Dialog
        ref="tokenDialogRef"
        type="edit"
        :title="t('WEBHOOK.TOKEN.TITLE')"
        :description="t('WEBHOOK.TOKEN.DESCRIPTION')"
        :confirm-button-label="t('WEBHOOK.TOKEN.DONE')"
      >
        <div
          v-if="createdWebhook"
          class="flex items-center gap-2 p-3 rounded-lg bg-n-alpha-1"
        >
          <code class="flex-1 text-sm break-all text-n-slate-12">
            {{ fullUrl(createdWebhook) }}
          </code>
          <Button
            icon="i-lucide-copy"
            color="slate"
            variant="ghost"
            size="sm"
            @click="copyUrl(createdWebhook)"
          />
        </div>
      </Dialog>

      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="t('WEBHOOK.DELETE_CONFIRM.TITLE')"
        :description="
          t('WEBHOOK.DELETE_CONFIRM.DESCRIPTION', {
            name: pendingDelete?.name,
          })
        "
        :confirm-button-label="t('WEBHOOK.DELETE_CONFIRM.CONFIRM')"
        @confirm="deleteWebhook"
      />
    </template>
  </SettingsLayout>
</template>
