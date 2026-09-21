<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import DealFieldExtractionsAPI from 'dashboard/api/dealFieldExtractions';
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

const fields = ref([]);
const isLoading = ref(false);
const applyingKey = ref(null);
const hasScanned = ref(false);

const castValue = field => {
  if (field.displayType === 'checkbox') return field.value === 'true';
  if (['number', 'currency', 'percent'].includes(field.displayType)) {
    return Number(field.value);
  }
  return field.value;
};

const extract = async () => {
  isLoading.value = true;
  try {
    const { data } = await DealFieldExtractionsAPI.extract(props.deal.id);
    fields.value = camelcaseKeys(data.payload, { deep: true });
    hasScanned.value = true;
  } catch (error) {
    useAlert(error?.response?.data?.error || t('DEALS.FIELD_SUGGESTIONS.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const skip = field => {
  fields.value = fields.value.filter(
    item => item.attributeKey !== field.attributeKey
  );
};

const apply = async field => {
  applyingKey.value = field.attributeKey;
  try {
    emit(
      'updated',
      await dealsStore.update(props.deal, {
        customAttributes: {
          ...props.deal.customAttributes,
          [field.attributeKey]: castValue(field),
        },
      })
    );
    skip(field);
    useAlert(t('DEALS.FIELD_SUGGESTIONS.APPLIED'));
  } catch {
    useAlert(t('DEALS.MESSAGES.UPDATE_ERROR'));
  } finally {
    applyingKey.value = null;
  }
};

watch(
  () => props.deal.id,
  () => {
    fields.value = [];
    hasScanned.value = false;
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
        {{ t('DEALS.FIELD_SUGGESTIONS.TITLE') }}
      </h4>
      <Button
        :label="t('DEALS.FIELD_SUGGESTIONS.GENERATE')"
        icon="i-lucide-sparkles"
        color="slate"
        variant="faded"
        size="sm"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="extract"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner :size="20" />
    </div>

    <div v-else-if="fields.length" class="flex flex-col gap-2">
      <div
        v-for="field in fields"
        :key="field.attributeKey"
        class="flex flex-col gap-1 p-3 text-sm rounded-lg bg-n-alpha-1"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-n-slate-11">{{ field.displayName }}</span>
          <span class="font-medium text-n-slate-12">{{ field.value }}</span>
        </div>
        <p class="mb-0 text-n-slate-11">{{ field.reason }}</p>
        <div class="flex justify-end gap-2">
          <Button
            :label="t('DEALS.FIELD_SUGGESTIONS.SKIP')"
            color="slate"
            variant="ghost"
            size="sm"
            @click="skip(field)"
          />
          <Button
            :label="t('DEALS.FIELD_SUGGESTIONS.APPLY')"
            size="sm"
            :is-loading="applyingKey === field.attributeKey"
            :disabled="applyingKey === field.attributeKey"
            @click="apply(field)"
          />
        </div>
      </div>
    </div>

    <p v-else class="mb-0 text-sm text-n-slate-11">
      {{
        hasScanned
          ? t('DEALS.FIELD_SUGGESTIONS.EMPTY')
          : t('DEALS.FIELD_SUGGESTIONS.HINT')
      }}
    </p>
  </div>
</template>
