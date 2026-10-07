<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  featureModels: {
    type: Array,
    required: true,
  },
  providers: {
    type: Array,
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

const groups = computed(() => {
  const grouped = new Map();
  props.featureModels.forEach(featureModel => {
    const list = grouped.get(featureModel.group) || [];
    list.push(featureModel);
    grouped.set(featureModel.group, list);
  });
  return [...grouped].map(([group, featureModels]) => ({
    group,
    label: t(`TEKOMI_SETTINGS.FEATURE_MODELS.GROUPS.${group.toUpperCase()}`),
    featureModels,
  }));
});

const customizedCount = computed(
  () =>
    props.featureModels.filter(featureModel => featureModel.customized).length
);

const supportsReasoning = featureKey => {
  const providerType = drafts[featureKey]?.provider_type;
  return props.providers.some(
    provider =>
      provider.provider_type === providerType && provider.supports_reasoning
  );
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
};

const remove = featureModel => {
  emit('remove', { featureKey: featureModel.feature_key });
};
</script>

<template>
  <details class="p-4 border rounded-xl border-n-weak">
    <summary class="text-sm font-medium cursor-pointer text-n-slate-12">
      {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.TOGGLE') }}
      <span class="ml-1 text-xs font-normal text-n-slate-10">
        {{
          t('TEKOMI_SETTINGS.FEATURE_MODELS.COUNT', { count: customizedCount })
        }}
      </span>
    </summary>
    <p class="mt-2 text-xs text-n-slate-10">
      {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.HINT') }}
    </p>
    <div v-for="item in groups" :key="item.group" class="mt-6">
      <h4
        class="mb-2 text-xs font-semibold tracking-wide uppercase text-n-slate-10"
      >
        {{ item.label }}
      </h4>
      <div class="grid gap-3">
        <div
          v-for="featureModel in item.featureModels"
          :key="featureModel.feature_key"
          class="grid gap-2 p-3 border rounded-lg border-n-weak"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-sm font-medium text-n-slate-12">
                {{ featureModel.name }}
              </p>
              <p class="text-xs text-n-slate-10">
                {{ featureModel.description }}
              </p>
            </div>
            <span
              class="px-2 py-1 text-xs font-medium rounded-lg shrink-0"
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
          <div class="grid gap-2 sm:grid-cols-3">
            <select
              v-model="drafts[featureModel.feature_key].provider_type"
              class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 focus:border-n-brand"
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
            <input
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
              class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white disabled:cursor-not-allowed disabled:opacity-50"
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
      </div>
    </div>
  </details>
</template>
