<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import DealsAPI from 'dashboard/api/deals';
import { camelizeDeal } from 'dashboard/stores/deals';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatVND, formatDealDate } from './constants';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const pipelinesStore = usePipelinesStore();

const deals = ref([]);
const isLoading = ref(false);

const stagesById = computed(() =>
  Object.fromEntries(
    pipelinesStore.records.flatMap(pipeline =>
      pipeline.stages.map(stage => [stage.id, stage])
    )
  )
);

const loadDeals = async () => {
  isLoading.value = true;
  try {
    const { data } = await DealsAPI.getByContact(props.contactId);
    deals.value = data.payload.map(camelizeDeal);
  } catch {
    useAlert(t('DEALS.CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch(() => props.contactId, loadDeals, { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-3 px-6 py-4">
    <div v-if="isLoading" class="flex justify-center py-6">
      <Spinner />
    </div>
    <p v-else-if="!deals.length" class="mb-0 text-sm text-n-slate-11">
      {{ t('DEALS.CONVERSATION.EMPTY') }}
    </p>
    <template v-else>
      <router-link
        v-for="deal in deals"
        :key="deal.id"
        :to="{ name: 'deals_show', params: { dealId: deal.id } }"
        class="flex flex-col gap-1 p-3 text-sm rounded-lg bg-n-alpha-1 hover:bg-n-alpha-2"
      >
        <span class="font-medium truncate text-n-slate-12">{{ deal.name }}</span>
        <span class="flex items-center gap-1.5 text-n-slate-11">
          <span
            v-if="stagesById[deal.stageId]"
            class="flex-shrink-0 rounded-sm size-2"
            :style="{ backgroundColor: stagesById[deal.stageId].color }"
          />
          {{ stagesById[deal.stageId]?.name }}
          <template v-if="deal.value !== null">
            · {{ formatVND(deal.value) }}
          </template>
          <template v-if="deal.expectedCloseDate">
            · {{ formatDealDate(deal.expectedCloseDate) }}
          </template>
        </span>
      </router-link>
    </template>
  </div>
</template>
