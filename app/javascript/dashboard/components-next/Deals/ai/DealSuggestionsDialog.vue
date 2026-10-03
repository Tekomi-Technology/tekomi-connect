<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import DealSuggestionsAPI from 'dashboard/api/dealSuggestions';
import DealsAPI from 'dashboard/api/deals';
import { useDealsStore } from 'dashboard/stores/deals';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatVND, formatDealDate } from '../constants';

const props = defineProps({
  stages: { type: Array, required: true },
});

const { t } = useI18n();
const dealsStore = useDealsStore();

const dialogRef = ref(null);
const suggestions = ref([]);
const isScanning = ref(false);
const creatingConversationId = ref(null);

const scan = async () => {
  isScanning.value = true;
  suggestions.value = [];
  try {
    const { data } = await DealSuggestionsAPI.scan();
    suggestions.value = camelcaseKeys(data.payload, { deep: true });
  } catch (error) {
    useAlert(error?.response?.data?.error || t('DEALS.SUGGESTIONS.ERROR'));
  } finally {
    isScanning.value = false;
  }
};

const open = () => {
  dialogRef.value?.open();
  scan();
};

const CONFIDENCE_LEVELS = ['high', 'medium', 'low'];

const confidenceLabel = confidence =>
  CONFIDENCE_LEVELS.includes(confidence)
    ? t(`DEALS.SUGGESTIONS.CONFIDENCE.${confidence.toUpperCase()}`)
    : '';

const dismiss = suggestion => {
  suggestions.value = suggestions.value.filter(
    item => item.conversationId !== suggestion.conversationId
  );
};

const createDeal = async suggestion => {
  creatingConversationId.value = suggestion.conversationId;
  try {
    const deal = await dealsStore.create({
      name: suggestion.name,
      value: suggestion.value,
      stage_id: props.stages[0]?.id,
      contact_id: suggestion.contact?.id || null,
      expected_close_date: suggestion.expectedCloseDate || null,
    });
    await DealsAPI.linkConversation(deal.id, suggestion.conversationId);
    dismiss(suggestion);
    useAlert(t('DEALS.SUGGESTIONS.CREATED'));
  } catch (error) {
    useAlert(error.message || t('DEALS.FORM.MESSAGES.ERROR'));
  } finally {
    creatingConversationId.value = null;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    :title="t('DEALS.SUGGESTIONS.TITLE')"
    :description="t('DEALS.SUGGESTIONS.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="t('DEALS.SUGGESTIONS.CLOSE')"
    overflow-y-auto
  >
    <div v-if="isScanning" class="flex flex-col items-center gap-2 py-8">
      <Spinner />
      <span class="text-sm text-n-slate-11">
        {{ t('DEALS.SUGGESTIONS.SCANNING') }}
      </span>
    </div>

    <p
      v-else-if="!suggestions.length"
      class="py-8 mb-0 text-sm text-center text-n-slate-11"
    >
      {{ t('DEALS.SUGGESTIONS.EMPTY') }}
    </p>

    <div v-else class="flex flex-col gap-3">
      <div
        v-for="suggestion in suggestions"
        :key="suggestion.conversationId"
        class="flex flex-col gap-2 p-3 text-sm border rounded-lg border-n-weak"
      >
        <div class="flex items-start justify-between gap-2">
          <span class="font-medium text-n-slate-12">{{ suggestion.name }}</span>
          <span
            v-if="confidenceLabel(suggestion.confidence)"
            class="flex-shrink-0 px-2 py-0.5 text-xs rounded-md text-n-slate-11 bg-n-alpha-1"
          >
            {{ confidenceLabel(suggestion.confidence) }}
          </span>
        </div>

        <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-n-slate-11">
          <span v-if="suggestion.contact" class="flex items-center gap-1.5">
            <Icon icon="i-lucide-contact" class="size-3.5" />
            {{ suggestion.contact.name }}
          </span>
          <span v-if="suggestion.value" class="flex items-center gap-1.5">
            <Icon icon="i-lucide-banknote" class="size-3.5" />
            {{ formatVND(suggestion.value) }}
          </span>
          <span
            v-if="suggestion.expectedCloseDate"
            class="flex items-center gap-1.5"
          >
            <Icon icon="i-lucide-calendar" class="size-3.5" />
            {{ formatDealDate(suggestion.expectedCloseDate) }}
          </span>
          <span class="flex items-center gap-1.5">
            <Icon icon="i-lucide-message-square" class="size-3.5" />
            #{{ suggestion.conversationId }}
          </span>
        </div>

        <p class="mb-0 text-n-slate-11">{{ suggestion.reason }}</p>

        <div class="flex justify-end gap-2">
          <Button
            :label="t('DEALS.SUGGESTIONS.DISMISS')"
            color="slate"
            variant="ghost"
            size="sm"
            @click="dismiss(suggestion)"
          />
          <Button
            :label="t('DEALS.SUGGESTIONS.CREATE')"
            size="sm"
            :is-loading="creatingConversationId === suggestion.conversationId"
            :disabled="creatingConversationId === suggestion.conversationId"
            @click="createDeal(suggestion)"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
