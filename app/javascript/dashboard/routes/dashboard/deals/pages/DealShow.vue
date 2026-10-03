<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useDealsStore } from 'dashboard/stores/deals';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DealDetail from 'dashboard/components-next/Deals/detail/DealDetail.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const dealsStore = useDealsStore();

const deleteDialogRef = ref(null);
const deal = computed(() => dealsStore.watchedDeal);

const goToPipeline = pipelineId => {
  router.push({
    name: 'deals_pipeline_index',
    params: { pipelineId: pipelineId || deal.value.pipelineId },
  });
};

const loadDeal = async () => {
  dealsStore.unwatchDeal();
  try {
    dealsStore.watchDeal(await dealsStore.show(route.params.dealId));
  } catch (error) {
    useAlert(error.message);
  }
};

const deleteDeal = async () => {
  deleteDialogRef.value?.close();
  const { pipelineId } = deal.value;
  try {
    await dealsStore.delete(deal.value);
    useAlert(t('DEALS.MESSAGES.DELETE_SUCCESS'));
    goToPipeline(pipelineId);
  } catch {
    useAlert(t('DEALS.MESSAGES.DELETE_ERROR'));
  }
};

watch(() => route.params.dealId, loadDeal, { immediate: true });

onMounted(() => {
  store.dispatch('agents/get');
});

onUnmounted(() => {
  dealsStore.unwatchDeal();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div v-if="!deal" class="flex justify-center py-10">
      <Spinner />
    </div>
    <div v-else class="w-full max-w-3xl px-6 py-6 mx-auto">
      <Button
        :label="t('DEALS.DETAIL.BACK')"
        icon="i-lucide-arrow-left"
        color="slate"
        variant="link"
        size="sm"
        class="mb-4"
        @click="goToPipeline()"
      />
      <DealDetail
        :deal="deal"
        @updated="dealsStore.watchDeal($event)"
        @delete="deleteDialogRef?.open()"
      />
    </div>
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('DEALS.DELETE_DIALOG.TITLE')"
      :description="t('DEALS.DELETE_DIALOG.DESCRIPTION', { count: 1 }, 1)"
      :confirm-button-label="t('DEALS.DELETE_DIALOG.CONFIRM')"
      @confirm="deleteDeal"
    />
  </section>
</template>
