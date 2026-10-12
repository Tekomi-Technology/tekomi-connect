<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  featureModels: {
    type: Array,
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
  savingKeys: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['save', 'remove']);

const { t } = useI18n();

const REASONING_OPTIONS = ['off', 'low', 'medium', 'high'];

const drafts = reactive({});
const paramsErrors = reactive({});
const editingKey = ref('');
const activeFilter = ref('all');

const buildDraft = featureModel => ({
  provider_type: featureModel.provider_type || '',
  model: featureModel.model || '',
  reasoning: featureModel.reasoning || '',
  params: Object.keys(featureModel.params || {}).length
    ? JSON.stringify(featureModel.params, null, 2)
    : '',
});

watch(
  () => props.featureModels,
  featureModels => {
    featureModels.forEach(featureModel => {
      drafts[featureModel.feature_key] = buildDraft(featureModel);
      paramsErrors[featureModel.feature_key] = '';
    });
  },
  { immediate: true }
);

const optionsByProvider = computed(() =>
  Object.fromEntries(
    Object.entries(props.models).map(([providerType, modelIds]) => [
      providerType,
      modelIds.map(modelId => ({ value: modelId, label: modelId })),
    ])
  )
);

const groupLabel = group =>
  t(`TEKOMI_SETTINGS.GROUPS.${group.toUpperCase()}`, group);

const customizedCount = computed(
  () => props.featureModels.filter(featureModel => featureModel.customized).length
);

const visibleFeatureModels = computed(() => {
  if (activeFilter.value === 'customized') {
    return props.featureModels.filter(featureModel => featureModel.customized);
  }
  if (activeFilter.value === 'inherited') {
    return props.featureModels.filter(featureModel => !featureModel.customized);
  }
  return props.featureModels;
});

const selectedProvider = featureKey =>
  props.providers.find(
    provider => provider.provider_type === drafts[featureKey]?.provider_type
  );

const modelOptions = featureKey =>
  optionsByProvider.value[drafts[featureKey]?.provider_type] || [];

const supportsReasoning = featureKey =>
  Boolean(selectedProvider(featureKey)?.supports_reasoning);

const isKeyMissing = featureKey => {
  const provider = selectedProvider(featureKey);
  return Boolean(provider) && !provider.configured;
};

const onProviderChange = featureKey => {
  drafts[featureKey].model = '';
};

const toggleEditing = featureKey => {
  editingKey.value = editingKey.value === featureKey ? '' : featureKey;
};

const save = featureModel => {
  const draft = drafts[featureModel.feature_key];
  let parsedParams = {};

  if (draft.params.trim()) {
    try {
      parsedParams = JSON.parse(draft.params);
    } catch (error) {
      paramsErrors[featureModel.feature_key] = t(
        'TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS_INVALID'
      );
      return;
    }
  }

  paramsErrors[featureModel.feature_key] = '';
  emit('save', {
    featureKey: featureModel.feature_key,
    payload: {
      provider_type: draft.provider_type,
      model: draft.model.trim(),
      reasoning: supportsReasoning(featureModel.feature_key)
        ? draft.reasoning
        : '',
      params: parsedParams,
    },
  });
  editingKey.value = '';
};

const remove = featureModel => {
  emit('remove', { featureKey: featureModel.feature_key });
  editingKey.value = '';
};
</script>

<template>
  <div class="flex flex-col">
    <div
      class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border-b border-n-weak"
    >
      <p class="text-xs text-n-slate-11">
        {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.HINT') }}
      </p>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="filter in [
            { key: 'all', label: t('TEKOMI_SETTINGS.FEATURE_MODELS.FILTER_ALL', { count: featureModels.length }) },
            { key: 'customized', label: t('TEKOMI_SETTINGS.FEATURE_MODELS.FILTER_CUSTOMIZED', { count: customizedCount }) },
            { key: 'inherited', label: t('TEKOMI_SETTINGS.FEATURE_MODELS.FILTER_INHERITED', { count: featureModels.length - customizedCount }) },
          ]"
          :key="filter.key"
          type="button"
          class="px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            activeFilter === filter.key
              ? 'border-n-brand bg-n-brand text-white'
              : 'border-n-weak text-n-slate-11'
          "
          @click="activeFilter = filter.key"
        >
          {{ filter.label }}
        </button>
      </div>
    </div>

    <div class="overflow-x-auto">
      <table class="w-full text-sm border-collapse">
        <thead>
          <tr class="text-left bg-n-alpha-1">
            <th class="px-4 py-2 text-xs font-medium text-n-slate-11">
              {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.COL_FEATURE') }}
            </th>
            <th class="px-4 py-2 text-xs font-medium text-n-slate-11">
              {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.COL_GROUP') }}
            </th>
            <th class="px-4 py-2 text-xs font-medium text-n-slate-11">
              {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.COL_MODEL') }}
            </th>
            <th class="px-4 py-2" />
          </tr>
        </thead>
        <tbody>
          <template
            v-for="featureModel in visibleFeatureModels"
            :key="featureModel.feature_key"
          >
            <tr class="border-t border-n-weak">
              <td class="px-4 py-3">
                <span class="block font-medium text-n-slate-12">
                  {{ featureModel.name }}
                </span>
                <span class="block text-xs text-n-slate-10">
                  {{ featureModel.description }}
                </span>
              </td>
              <td class="px-4 py-3 text-xs text-n-slate-11">
                {{ groupLabel(featureModel.group) }}
              </td>
              <td class="px-4 py-3">
                <span
                  v-if="featureModel.customized"
                  class="px-2 py-1 font-mono text-xs rounded-lg bg-n-teal-3 text-n-teal-11"
                >
                  {{ featureModel.provider_type }} · {{ featureModel.model }}
                </span>
                <span v-else class="text-xs italic text-n-slate-10">
                  {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.INHERITED') }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <button
                  type="button"
                  class="px-3 py-1.5 text-xs font-medium border rounded-lg border-n-weak text-n-slate-12"
                  @click="toggleEditing(featureModel.feature_key)"
                >
                  {{
                    editingKey === featureModel.feature_key
                      ? t('TEKOMI_SETTINGS.FEATURE_MODELS.CLOSE')
                      : t('TEKOMI_SETTINGS.FEATURE_MODELS.CONFIGURE')
                  }}
                </button>
              </td>
            </tr>

            <tr
              v-if="editingKey === featureModel.feature_key"
              class="border-t border-n-weak bg-n-alpha-1"
            >
              <td colspan="4" class="px-4 py-4">
                <div class="flex flex-col gap-3">
                  <div class="grid gap-2 sm:grid-cols-3">
                    <select
                      v-model="drafts[featureModel.feature_key].provider_type"
                      class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 focus:border-n-brand"
                      @change="onProviderChange(featureModel.feature_key)"
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

                    <ComboBox
                      v-if="modelOptions(featureModel.feature_key).length"
                      v-model="drafts[featureModel.feature_key].model"
                      :options="modelOptions(featureModel.feature_key)"
                      :display-label="drafts[featureModel.feature_key].model"
                      :placeholder="
                        t('TEKOMI_SETTINGS.FEATURE_MODELS.SELECT_MODEL')
                      "
                      :search-placeholder="
                        t('TEKOMI_SETTINGS.FEATURE_MODELS.SEARCH_MODEL')
                      "
                      :empty-state="t('TEKOMI_SETTINGS.FEATURE_MODELS.NO_MODEL')"
                    />
                    <input
                      v-else
                      v-model="drafts[featureModel.feature_key].model"
                      type="text"
                      spellcheck="false"
                      :placeholder="
                        featureModel.suggested_model ||
                        t('TEKOMI_SETTINGS.FEATURE_MODELS.MODEL_PLACEHOLDER')
                      "
                      class="w-full px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
                    />

                    <select
                      v-if="supportsReasoning(featureModel.feature_key)"
                      v-model="drafts[featureModel.feature_key].reasoning"
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
                  </div>

                  <p
                    v-if="isKeyMissing(featureModel.feature_key)"
                    class="text-xs text-n-amber-11"
                  >
                    {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.KEY_MISSING') }}
                  </p>

                  <details>
                    <summary class="text-xs cursor-pointer text-n-slate-10">
                      {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS') }}
                    </summary>
                    <textarea
                      v-model="drafts[featureModel.feature_key].params"
                      rows="4"
                      spellcheck="false"
                      :placeholder="
                        t('TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS_PLACEHOLDER')
                      "
                      class="w-full px-3 py-2 mt-1 font-mono text-xs bg-transparent border rounded-lg resize-y border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
                    />
                    <p class="mt-1 text-xs text-n-slate-10">
                      {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS_HINT') }}
                    </p>
                  </details>

                  <p
                    v-if="paramsErrors[featureModel.feature_key]"
                    class="text-xs text-n-ruby-11"
                  >
                    {{ paramsErrors[featureModel.feature_key] }}
                  </p>

                  <div class="flex flex-wrap gap-2">
                    <button
                      type="button"
                      class="px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand disabled:cursor-not-allowed disabled:opacity-50"
                      :disabled="
                        savingKeys[featureModel.feature_key] ||
                        !drafts[featureModel.feature_key].provider_type ||
                        !drafts[featureModel.feature_key].model.trim()
                      "
                      @click="save(featureModel)"
                    >
                      {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE') }}
                    </button>
                    <button
                      v-if="featureModel.customized"
                      type="button"
                      class="px-4 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-11 disabled:cursor-not-allowed disabled:opacity-50"
                      :disabled="savingKeys[featureModel.feature_key]"
                      @click="remove(featureModel)"
                    >
                      {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.RESTORE') }}
                    </button>
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>
  </div>
</template>
