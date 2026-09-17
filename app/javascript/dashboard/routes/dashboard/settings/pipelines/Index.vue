<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import PipelineStagesEditor from './PipelineStagesEditor.vue';

const { t } = useI18n();
const pipelinesStore = usePipelinesStore();

const selectedPipelineId = ref(null);
const pipelineName = ref('');
const newPipelineName = ref('');
const createDialogRef = ref(null);
const deleteDialogRef = ref(null);

const pipelines = computed(() => pipelinesStore.records);
const selectedPipeline = computed(() =>
  pipelinesStore.getPipeline(selectedPipelineId.value)
);

const withAlert = async request => {
  try {
    return await request();
  } catch (error) {
    useAlert(error.message);
    return null;
  }
};

const openCreateDialog = () => {
  newPipelineName.value = '';
  createDialogRef.value?.open();
};

const createPipeline = async () => {
  if (!newPipelineName.value.trim()) return;
  const pipeline = await withAlert(() =>
    pipelinesStore.create(newPipelineName.value.trim())
  );
  if (!pipeline) return;
  createDialogRef.value?.close();
  selectedPipelineId.value = pipeline.id;
};

const renamePipeline = () => {
  const name = pipelineName.value.trim();
  if (!name || name === selectedPipeline.value.name) {
    pipelineName.value = selectedPipeline.value.name;
    return;
  }
  withAlert(() => pipelinesStore.update(selectedPipeline.value.id, name));
};

const reorderPipelines = async nextPipelines => {
  const result = await withAlert(() =>
    pipelinesStore.reorder(nextPipelines.map(pipeline => pipeline.id))
  );
  if (!result) pipelinesStore.fetch();
};

const deletePipeline = async () => {
  deleteDialogRef.value?.close();
  try {
    await pipelinesStore.delete(selectedPipeline.value.id);
    useAlert(t('PIPELINES_SETTINGS.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(error.message);
  }
};

watch(
  pipelines,
  records => {
    if (!pipelinesStore.getPipeline(selectedPipelineId.value)) {
      selectedPipelineId.value = records[0]?.id || null;
    }
  },
  { immediate: true }
);

watch(
  selectedPipeline,
  pipeline => {
    pipelineName.value = pipeline?.name || '';
  },
  { immediate: true }
);

onMounted(() => {
  pipelinesStore.fetch().catch(error => useAlert(error.message));
});
</script>

<template>
  <SettingsLayout
    :is-loading="pipelinesStore.uiFlags.isFetching && !pipelines.length"
    :loading-message="t('PIPELINES_SETTINGS.LOADING')"
    :no-records-found="!pipelines.length"
    :no-records-message="t('PIPELINES_SETTINGS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('PIPELINES_SETTINGS.HEADER.TITLE')"
        :description="t('PIPELINES_SETTINGS.HEADER.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('PIPELINES_SETTINGS.CREATE.BUTTON')"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreateDialog"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="grid gap-6 mt-4 md:grid-cols-[16rem_1fr]">
        <Draggable
          :model-value="pipelines"
          item-key="id"
          handle=".pipeline-handle"
          ghost-class="opacity-40"
          animation="150"
          class="flex flex-col gap-1"
          @update:model-value="reorderPipelines"
        >
          <template #item="{ element: pipeline }">
            <button
              type="button"
              class="flex items-center gap-2 px-2 py-2 text-sm rounded-lg text-start text-n-slate-12"
              :class="
                pipeline.id === selectedPipelineId
                  ? 'bg-n-alpha-2'
                  : 'hover:bg-n-alpha-1'
              "
              @click="selectedPipelineId = pipeline.id"
            >
              <Icon
                icon="i-lucide-grip-vertical"
                class="flex-shrink-0 pipeline-handle size-4 cursor-grab text-n-slate-10"
              />
              <span class="flex-1 truncate">{{ pipeline.name }}</span>
              <span class="text-xs text-n-slate-11">
                {{ pipeline.stages.length }}
              </span>
            </button>
          </template>
        </Draggable>

        <div v-if="selectedPipeline" class="flex flex-col gap-6">
          <div class="flex items-end gap-2">
            <Input
              v-model="pipelineName"
              :label="t('PIPELINES_SETTINGS.NAME_LABEL')"
              class="flex-1"
              @blur="renamePipeline"
              @enter="renamePipeline"
            />
            <Button
              :label="t('PIPELINES_SETTINGS.DELETE.BUTTON')"
              icon="i-lucide-trash"
              color="ruby"
              variant="faded"
              size="sm"
              @click="deleteDialogRef?.open()"
            />
          </div>
          <PipelineStagesEditor :pipeline="selectedPipeline" />
        </div>
      </div>
    </template>

    <Dialog
      ref="createDialogRef"
      :title="t('PIPELINES_SETTINGS.CREATE.TITLE')"
      :confirm-button-label="t('PIPELINES_SETTINGS.CREATE.CONFIRM')"
      :disable-confirm-button="!newPipelineName.trim()"
      :is-loading="pipelinesStore.uiFlags.isSaving"
      @confirm="createPipeline"
    >
      <Input
        v-model="newPipelineName"
        :placeholder="t('PIPELINES_SETTINGS.NAME_LABEL')"
        :message="t('PIPELINES_SETTINGS.CREATE.HINT')"
        autofocus
      />
    </Dialog>
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="
        t('PIPELINES_SETTINGS.DELETE.TITLE', { name: selectedPipeline?.name })
      "
      :description="t('PIPELINES_SETTINGS.DELETE.DESCRIPTION')"
      :confirm-button-label="t('PIPELINES_SETTINGS.DELETE.CONFIRM')"
      @confirm="deletePipeline"
    />
  </SettingsLayout>
</template>
