<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  pipeline: { type: Object, required: true },
});

const STAGE_TYPES = ['open', 'won', 'lost'];
const NEW_STAGE_COLOR = '#6B7280';

const { t } = useI18n();
const pipelinesStore = usePipelinesStore();

const deleteDialogRef = ref(null);
const stageToDelete = ref(null);
const moveToStageId = ref('');

const stageTypeOptions = computed(() =>
  STAGE_TYPES.map(type => ({
    value: type,
    label: t(`PIPELINES_SETTINGS.STAGE_TYPES.${type.toUpperCase()}`),
  }))
);
const moveTargetOptions = computed(() =>
  props.pipeline.stages
    .filter(stage => stage.id !== stageToDelete.value?.id)
    .map(stage => ({ value: stage.id, label: stage.name }))
);

const withAlert = async request => {
  try {
    await request();
  } catch (error) {
    useAlert(error.message);
  }
};

const updateStage = (stage, changes) => {
  const hasChanges = Object.entries(changes).some(
    ([key, value]) => stage[key] !== value
  );
  if (!hasChanges) return;
  withAlert(() =>
    pipelinesStore.updateStage(props.pipeline.id, stage.id, changes)
  );
};

const renameStage = (stage, event) => {
  const name = event.target.value.trim();
  if (name) updateStage(stage, { name });
  else event.target.value = stage.name;
};

const addStage = () => {
  withAlert(() =>
    pipelinesStore.createStage(props.pipeline.id, {
      name: t('PIPELINES_SETTINGS.STAGES.NEW_STAGE_NAME'),
      color: NEW_STAGE_COLOR,
      stageType: 'open',
    })
  );
};

const reorderStages = stages => {
  withAlert(() =>
    pipelinesStore.reorderStages(
      props.pipeline.id,
      stages.map(stage => stage.id)
    )
  );
};

const openDeleteDialog = stage => {
  stageToDelete.value = stage;
  moveToStageId.value = '';
  deleteDialogRef.value?.open();
};

const deleteStage = async () => {
  deleteDialogRef.value?.close();
  await withAlert(() =>
    pipelinesStore.deleteStage(
      props.pipeline.id,
      stageToDelete.value.id,
      moveToStageId.value
    )
  );
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-between">
      <h3 class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('PIPELINES_SETTINGS.STAGES.TITLE') }}
      </h3>
      <Button
        :label="t('PIPELINES_SETTINGS.STAGES.ADD')"
        icon="i-lucide-plus"
        color="slate"
        variant="faded"
        size="sm"
        @click="addStage"
      />
    </div>
    <Draggable
      :model-value="pipeline.stages"
      item-key="id"
      handle=".stage-handle"
      ghost-class="opacity-40"
      animation="150"
      class="flex flex-col gap-2"
      @update:model-value="reorderStages"
    >
      <template #item="{ element: stage }">
        <div
          class="flex items-center gap-2 p-2 border rounded-lg border-n-weak bg-n-solid-2"
        >
          <Icon
            icon="i-lucide-grip-vertical"
            class="flex-shrink-0 stage-handle size-4 cursor-grab text-n-slate-10"
          />
          <input
            type="color"
            :value="stage.color"
            class="flex-shrink-0 p-0 mb-0 border-0 rounded cursor-pointer size-7 bg-transparent"
            @change="updateStage(stage, { color: $event.target.value })"
          />
          <input
            :value="stage.name"
            class="flex-1 min-w-0 px-2 py-1.5 mb-0 text-sm rounded-md reset-base bg-n-alpha-1 text-n-slate-12"
            @blur="renameStage(stage, $event)"
            @keydown.enter="$event.target.blur()"
          />
          <Select
            :model-value="stage.stageType"
            :options="stageTypeOptions"
            @update:model-value="updateStage(stage, { stageType: $event })"
          />
          <Button
            icon="i-lucide-trash"
            color="ruby"
            variant="ghost"
            size="sm"
            :disabled="pipeline.stages.length <= 1"
            @click="openDeleteDialog(stage)"
          />
        </div>
      </template>
    </Draggable>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="
        t('PIPELINES_SETTINGS.STAGES.DELETE.TITLE', {
          name: stageToDelete?.name,
        })
      "
      :description="t('PIPELINES_SETTINGS.STAGES.DELETE.DESCRIPTION')"
      :confirm-button-label="t('PIPELINES_SETTINGS.STAGES.DELETE.CONFIRM')"
      @confirm="deleteStage"
    >
      <Select
        v-model="moveToStageId"
        :options="moveTargetOptions"
        :placeholder="t('PIPELINES_SETTINGS.STAGES.DELETE.MOVE_TO')"
        class="w-full"
      />
    </Dialog>
  </div>
</template>
