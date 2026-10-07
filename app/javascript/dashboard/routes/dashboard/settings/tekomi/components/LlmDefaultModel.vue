<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  providers: {
    type: Array,
    required: true,
  },
  models: {
    type: Object,
    required: true,
  },
  value: {
    type: Object,
    required: true,
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['save']);

const { t } = useI18n();

const providerType = ref(props.value.provider_type || '');
const model = ref(props.value.model || '');

watch(
  () => props.value,
  newValue => {
    providerType.value = newValue.provider_type || '';
    model.value = newValue.model || '';
  }
);

const modelOptions = computed(() =>
  (props.models[providerType.value] || []).map(modelId => ({
    value: modelId,
    label: modelId,
  }))
);

const hasCatalog = computed(() => modelOptions.value.length > 0);

const selectedProvider = computed(() =>
  props.providers.find(
    provider => provider.provider_type === providerType.value
  )
);

const isKeyMissing = computed(
  () => providerType.value !== '' && !selectedProvider.value?.configured
);

const isDirty = computed(
  () =>
    providerType.value !== (props.value.provider_type || '') ||
    model.value !== (props.value.model || '')
);

const onProviderChange = () => {
  model.value = '';
};

const save = () => {
  emit('save', {
    provider_type: providerType.value,
    model: model.value.trim(),
  });
};
</script>

<template>
  <div class="grid gap-3 p-4 border rounded-xl border-n-weak">
    <div class="grid gap-3 sm:grid-cols-2">
      <label class="grid gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.PROVIDER') }}
        </span>
        <select
          v-model="providerType"
          class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 focus:border-n-brand"
          @change="onProviderChange"
        >
          <option value="">
            {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.SELECT_PROVIDER') }}
          </option>
          <option
            v-for="provider in providers"
            :key="provider.provider_type"
            :value="provider.provider_type"
          >
            {{ provider.name }}
          </option>
        </select>
      </label>
      <label class="grid gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.MODEL') }}
        </span>
        <ComboBox
          v-if="hasCatalog"
          v-model="model"
          :options="modelOptions"
          :display-label="model"
          :placeholder="t('TEKOMI_SETTINGS.DEFAULT_MODEL.SELECT_MODEL')"
          :search-placeholder="t('TEKOMI_SETTINGS.DEFAULT_MODEL.SEARCH_MODEL')"
          :empty-state="t('TEKOMI_SETTINGS.DEFAULT_MODEL.NO_MODEL')"
        />
        <input
          v-else
          v-model="model"
          type="text"
          spellcheck="false"
          :placeholder="t('TEKOMI_SETTINGS.DEFAULT_MODEL.MODEL_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
        />
      </label>
    </div>
    <p v-if="isKeyMissing" class="text-xs text-n-amber-11">
      {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.KEY_MISSING') }}
    </p>
    <div>
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="isSaving || !isDirty || !providerType || !model.trim()"
        @click="save"
      >
        {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.SAVE') }}
      </button>
    </div>
  </div>
</template>
