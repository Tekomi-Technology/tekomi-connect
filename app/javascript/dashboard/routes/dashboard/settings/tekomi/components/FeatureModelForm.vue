<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  featureModel: {
    type: Object,
    required: true,
  },
  draft: {
    type: Object,
    required: true,
  },
  providers: {
    type: Array,
    required: true,
  },
  models: {
    type: Object,
    required: true,
  },
  paramsError: {
    type: String,
    default: '',
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['save', 'remove']);

const { t } = useI18n();

const REASONING_OPTIONS = ['off', 'low', 'medium', 'high'];

const groupLabel = computed(() =>
  t(
    `TEKOMI_SETTINGS.GROUPS.${props.featureModel.group.toUpperCase()}`,
    props.featureModel.group
  )
);

const selectedProvider = computed(() =>
  props.providers.find(
    provider => provider.provider_type === props.draft.provider_type
  )
);

const modelOptions = computed(() =>
  (props.models[props.draft.provider_type] || []).map(modelId => ({
    value: modelId,
    label: modelId,
  }))
);

const supportsReasoning = computed(() =>
  Boolean(selectedProvider.value?.supports_reasoning)
);

const isKeyMissing = computed(
  () => Boolean(selectedProvider.value) && !selectedProvider.value.configured
);

const canSave = computed(
  () => props.draft.provider_type && props.draft.model.trim()
);

const onProviderChange = () => {
  props.draft.model = '';
};
</script>

<template>
  <div
    class="flex flex-col border rounded-xl border-n-weak bg-n-solid-1 min-h-[26rem]"
  >
    <div class="p-4 border-b border-n-weak">
      <div class="flex flex-wrap items-center gap-2">
        <h2 class="text-base font-medium text-n-slate-12">
          {{ featureModel.name }}
        </h2>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-lg"
          :class="
            featureModel.customized
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-slate-3 text-n-slate-11'
          "
        >
          {{
            featureModel.customized
              ? t('TEKOMI_SETTINGS.FEATURE_MODELS.CUSTOMIZED')
              : t('TEKOMI_SETTINGS.FEATURE_MODELS.INHERITED')
          }}
        </span>
      </div>
      <p class="mt-1 text-xs text-n-slate-11">
        {{ featureModel.description }} · {{ groupLabel }}
      </p>
    </div>

    <div class="flex flex-col gap-4 p-4">
      <div class="grid gap-3 sm:grid-cols-3">
        <label class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.PROVIDER') }}
          </span>
          <select
            v-model="draft.provider_type"
            class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 focus:border-n-brand"
            @change="onProviderChange"
          >
            <option value="">
              {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.SELECT_PROVIDER') }}
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

        <label class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('TEKOMI_SETTINGS.DEFAULT_MODEL.MODEL') }}
          </span>
          <ComboBox
            v-if="modelOptions.length"
            v-model="draft.model"
            :options="modelOptions"
            :display-label="draft.model"
            :placeholder="t('TEKOMI_SETTINGS.FEATURE_MODELS.SELECT_MODEL')"
            :search-placeholder="
              t('TEKOMI_SETTINGS.FEATURE_MODELS.SEARCH_MODEL')
            "
            :empty-state="t('TEKOMI_SETTINGS.FEATURE_MODELS.NO_MODEL')"
          />
          <input
            v-else
            v-model="draft.model"
            type="text"
            spellcheck="false"
            :placeholder="
              featureModel.suggested_model ||
              t('TEKOMI_SETTINGS.FEATURE_MODELS.MODEL_PLACEHOLDER')
            "
            class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
          />
        </label>

        <label v-if="supportsReasoning" class="flex flex-col gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.REASONING_LABEL') }}
          </span>
          <select
            v-model="draft.reasoning"
            class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 focus:border-n-brand"
          >
            <option value="">
              {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.REASONING.DEFAULT') }}
            </option>
            <option
              v-for="option in REASONING_OPTIONS"
              :key="option"
              :value="option"
            >
              {{
                t(
                  `TEKOMI_SETTINGS.FEATURE_MODELS.REASONING.${option.toUpperCase()}`
                )
              }}
            </option>
          </select>
        </label>
      </div>

      <p v-if="isKeyMissing" class="text-xs text-n-amber-11">
        {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.KEY_MISSING') }}
      </p>

      <details>
        <summary class="text-xs cursor-pointer text-n-slate-10">
          {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS') }}
        </summary>
        <textarea
          v-model="draft.params"
          rows="4"
          spellcheck="false"
          :placeholder="t('TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS_PLACEHOLDER')"
          class="w-full px-3 py-2 mt-1 font-mono text-xs bg-transparent border rounded-lg resize-y border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
        />
        <p class="mt-1 text-xs text-n-slate-10">
          {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS_HINT') }}
        </p>
      </details>

      <p v-if="paramsError" class="text-xs text-n-ruby-11">
        {{ paramsError }}
      </p>
    </div>

    <div
      class="flex flex-wrap items-center justify-between gap-3 p-4 mt-auto border-t border-n-weak"
    >
      <span class="text-xs text-n-slate-10">
        {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.HINT') }}
      </span>
      <div class="flex flex-wrap gap-2">
        <button
          v-if="featureModel.customized"
          type="button"
          class="px-4 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-11 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isSaving"
          @click="emit('remove')"
        >
          {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.RESTORE') }}
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isSaving || !canSave"
          @click="emit('save')"
        >
          {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE') }}
        </button>
      </div>
    </div>
  </div>
</template>
