<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import DealSummariesAPI from 'dashboard/api/dealSummaries';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  dealId: { type: Number, required: true },
});

const { t } = useI18n();

const summary = ref('');
const highlights = ref([]);
const isLoading = ref(false);

const generate = async () => {
  isLoading.value = true;
  try {
    const { data } = await DealSummariesAPI.generate(props.dealId);
    summary.value = data.payload.summary;
    highlights.value = data.payload.highlights || [];
  } catch (error) {
    useAlert(error?.response?.data?.error || t('DEALS.SUMMARY.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.dealId,
  () => {
    summary.value = '';
    highlights.value = [];
  }
);
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between gap-2">
      <h4 class="flex items-center gap-2 mb-0 text-sm font-medium text-n-slate-12">
        <Icon icon="i-woot-tekomi" class="size-4 text-n-brand" />
        {{ t('DEALS.SUMMARY.TITLE') }}
      </h4>
      <Button
        :label="summary ? t('DEALS.SUMMARY.REFRESH') : t('DEALS.SUMMARY.GENERATE')"
        :icon="summary ? 'i-lucide-refresh-cw' : 'i-lucide-sparkles'"
        color="slate"
        variant="faded"
        size="sm"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="generate"
      />
    </div>

    <div v-if="isLoading && !summary" class="flex justify-center py-4">
      <Spinner :size="20" />
    </div>

    <div v-else-if="summary" class="flex flex-col gap-2 p-3 text-sm rounded-lg bg-n-alpha-1">
      <p class="mb-0 whitespace-pre-line text-n-slate-12">{{ summary }}</p>
      <ul v-if="highlights.length" class="flex flex-col gap-1 pl-4 list-disc text-n-slate-11">
        <li v-for="(highlight, index) in highlights" :key="index">
          {{ highlight }}
        </li>
      </ul>
    </div>

    <p v-else class="mb-0 text-sm text-n-slate-11">
      {{ t('DEALS.SUMMARY.HINT') }}
    </p>
  </div>
</template>
