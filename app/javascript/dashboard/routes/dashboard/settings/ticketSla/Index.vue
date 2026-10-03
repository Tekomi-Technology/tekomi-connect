<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import StageSlaRow from './StageSlaRow.vue';

const { t } = useI18n();
const pipelinesStore = useTicketPipelinesStore();

const savingStageId = ref(null);

const saveStage = async (pipelineId, { stageId, sla, autoAdvanceFields }) => {
  savingStageId.value = stageId;
  try {
    await pipelinesStore.updateStage(pipelineId, stageId, {
      autoAdvanceFields,
      sla,
    });
    useAlert(t('TICKET_SLA.MESSAGES.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('TICKET_SLA.MESSAGES.SAVE_ERROR'));
  } finally {
    savingStageId.value = null;
  }
};

onMounted(() => {
  pipelinesStore.fetch().catch(error => useAlert(error.message));
});
</script>

<template>
  <SettingsLayout
    :is-loading="pipelinesStore.uiFlags.isFetching"
    :loading-message="t('TICKET_SLA.LOADING')"
    :no-records-found="
      !pipelinesStore.uiFlags.isFetching && !pipelinesStore.records.length
    "
    :no-records-message="t('TICKET_SLA.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET_SLA.HEADER')"
        :description="t('TICKET_SLA.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <section
          v-for="pipeline in pipelinesStore.records"
          :key="pipeline.id"
          class="border rounded-xl border-n-weak bg-n-solid-1"
        >
          <header class="px-4 py-3 border-b border-n-weak">
            <h2 class="font-medium text-n-slate-12">{{ pipeline.name }}</h2>
          </header>
          <StageSlaRow
            v-for="(stage, index) in pipeline.stages"
            :key="stage.id"
            :stage="stage"
            :is-last="index === pipeline.stages.length - 1"
            :is-saving="savingStageId === stage.id"
            @save="saveStage(pipeline.id, $event)"
          />
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
