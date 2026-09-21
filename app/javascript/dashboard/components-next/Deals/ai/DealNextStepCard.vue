<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import DealNextStepsAPI from 'dashboard/api/dealNextSteps';
import { useDealsStore } from 'dashboard/stores/deals';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  deal: { type: Object, required: true },
});

const emit = defineEmits(['updated']);

const { t } = useI18n();
const dealsStore = useDealsStore();

const advice = ref(null);
const isLoading = ref(false);
const isMoving = ref(false);

const generate = async () => {
  isLoading.value = true;
  try {
    const { data } = await DealNextStepsAPI.generate(props.deal.id);
    advice.value = camelcaseKeys(data.payload, { deep: true });
  } catch (error) {
    useAlert(error?.response?.data?.error || t('DEALS.NEXT_STEP.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const moveToSuggestedStage = async () => {
  isMoving.value = true;
  try {
    emit(
      'updated',
      await dealsStore.move(props.deal, {
        stageId: advice.value.suggestedStage.id,
        position: props.deal.position,
      })
    );
    advice.value = { ...advice.value, suggestedStage: null };
    useAlert(t('DEALS.NEXT_STEP.MOVED'));
  } catch {
    useAlert(t('DEALS.MESSAGES.UPDATE_ERROR'));
  } finally {
    isMoving.value = false;
  }
};

watch(
  () => props.deal.id,
  () => {
    advice.value = null;
  }
);
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between gap-2">
      <h4
        class="flex items-center gap-2 mb-0 text-sm font-medium text-n-slate-12"
      >
        <Icon icon="i-woot-tekomi" class="size-4 text-n-brand" />
        {{ t('DEALS.NEXT_STEP.TITLE') }}
      </h4>
      <Button
        :label="advice ? t('DEALS.NEXT_STEP.REFRESH') : t('DEALS.NEXT_STEP.GENERATE')"
        :icon="advice ? 'i-lucide-refresh-cw' : 'i-lucide-sparkles'"
        color="slate"
        variant="faded"
        size="sm"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="generate"
      />
    </div>

    <div v-if="isLoading && !advice" class="flex justify-center py-4">
      <Spinner :size="20" />
    </div>

    <div
      v-else-if="advice"
      class="flex flex-col gap-2 p-3 text-sm rounded-lg bg-n-alpha-1"
    >
      <p class="mb-0 text-n-slate-12">{{ advice.nextStep }}</p>
      <p class="mb-0 text-n-slate-11">{{ advice.reason }}</p>
      <div v-if="advice.suggestedStage" class="flex items-center gap-2 pt-1">
        <Button
          :label="
            t('DEALS.NEXT_STEP.MOVE_TO', { stage: advice.suggestedStage.name })
          "
          size="sm"
          :is-loading="isMoving"
          :disabled="isMoving"
          @click="moveToSuggestedStage"
        />
      </div>
    </div>

    <p v-else class="mb-0 text-sm text-n-slate-11">
      {{ t('DEALS.NEXT_STEP.HINT') }}
    </p>
  </div>
</template>
