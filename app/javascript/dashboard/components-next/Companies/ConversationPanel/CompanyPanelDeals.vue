<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { usePipelinesStore } from 'dashboard/stores/pipelines';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatVND } from 'dashboard/components-next/Deals/constants';

defineProps({
  deals: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

const { t } = useI18n();
const router = useRouter();
const pipelinesStore = usePipelinesStore();

const stagesById = computed(() =>
  Object.fromEntries(
    pipelinesStore.records
      .flatMap(pipeline => pipeline.stages)
      .map(stage => [stage.id, stage])
  )
);

onMounted(() => {
  if (!pipelinesStore.records.length) pipelinesStore.fetch();
});

const openDeal = deal => {
  router.push({ name: 'deals_show', params: { dealId: deal.id } });
};
</script>

<template>
  <div
    v-if="isLoading && !deals.length"
    class="flex items-center justify-center py-10 text-n-slate-11"
  >
    <Spinner />
  </div>

  <div v-else-if="deals.length" class="flex flex-col gap-2 px-4 py-3">
    <button
      v-for="deal in deals"
      :key="deal.id"
      type="button"
      class="flex flex-col w-full gap-1 p-3 text-sm text-left rounded-lg bg-n-alpha-1 hover:bg-n-alpha-2"
      @click="openDeal(deal)"
    >
      <span class="font-medium truncate text-n-slate-12">{{ deal.name }}</span>
      <span class="flex items-center gap-1.5 truncate text-n-slate-11">
        <span
          v-if="stagesById[deal.stageId]"
          class="flex-shrink-0 rounded-sm size-2"
          :style="{ backgroundColor: stagesById[deal.stageId].color }"
        />
        {{ stagesById[deal.stageId]?.name }}
        <template v-if="deal.value !== null && deal.value !== undefined">
          · {{ formatVND(deal.value) }}
        </template>
      </span>
    </button>
  </div>

  <p
    v-else
    class="px-4 py-8 mx-4 text-sm text-center border border-dashed rounded-xl border-n-strong text-n-slate-11"
  >
    {{ t('COMPANIES.CONVERSATION_PANEL.DEALS.EMPTY') }}
  </p>
</template>
