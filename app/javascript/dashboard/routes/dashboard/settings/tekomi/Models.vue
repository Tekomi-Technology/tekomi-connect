<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';

import SettingsShell from './SettingsShell.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import LlmDefaultModel from './components/LlmDefaultModel.vue';
import FeatureModelList from './components/FeatureModelList.vue';
import FeatureModelForm from './components/FeatureModelForm.vue';

const { t } = useI18n();

const tekomiConfigStore = useTekomiConfigStore();
const { uiFlags, llmProviders, llmDefault, llmFeatureModels, llmModels } =
  storeToRefs(tekomiConfigStore);

const isSavingDefault = ref(false);
const savingKeys = reactive({});
const drafts = reactive({});
const paramsErrors = reactive({});
const selectedKey = ref('');

const TIERS = ['OVERRIDE', 'FIXED', 'DEFAULT'];

const buildDraft = featureModel => ({
  provider_type: featureModel.provider_type || '',
  model: featureModel.model || '',
  reasoning: featureModel.reasoning || '',
  params: Object.keys(featureModel.params || {}).length
    ? JSON.stringify(featureModel.params, null, 2)
    : '',
});

watch(
  llmFeatureModels,
  featureModels => {
    featureModels.forEach(featureModel => {
      drafts[featureModel.feature_key] = buildDraft(featureModel);
      paramsErrors[featureModel.feature_key] = '';
    });
    if (!selectedKey.value && featureModels.length) {
      selectedKey.value = featureModels[0].feature_key;
    }
  },
  { immediate: true }
);

const selected = computed(() =>
  llmFeatureModels.value.find(
    featureModel => featureModel.feature_key === selectedKey.value
  )
);

async function saveDefaultModel(payload) {
  isSavingDefault.value = true;
  try {
    await tekomiConfigStore.updatePreferences({ llm_default: payload });
    useAlert(t('TEKOMI_SETTINGS.DEFAULT_MODEL.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.DEFAULT_MODEL.SAVE_ERROR'));
  } finally {
    isSavingDefault.value = false;
  }
}

async function saveFeatureModel() {
  const featureKey = selectedKey.value;
  const draft = drafts[featureKey];
  let parsedParams = {};

  if (draft.params.trim()) {
    try {
      parsedParams = JSON.parse(draft.params);
    } catch (error) {
      paramsErrors[featureKey] = t(
        'TEKOMI_SETTINGS.FEATURE_MODELS.PARAMS_INVALID'
      );
      return;
    }
  }

  paramsErrors[featureKey] = '';
  savingKeys[featureKey] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      llm_feature_models: {
        [featureKey]: {
          provider_type: draft.provider_type,
          model: draft.model.trim(),
          reasoning: draft.reasoning,
          params: parsedParams,
        },
      },
    });
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE_ERROR'));
  } finally {
    savingKeys[featureKey] = false;
  }
}

async function removeFeatureModel() {
  const featureKey = selectedKey.value;
  savingKeys[featureKey] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      llm_feature_models: { [featureKey]: { remove: true } },
    });
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.RESTORE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE_ERROR'));
  } finally {
    savingKeys[featureKey] = false;
  }
}

onMounted(() => tekomiConfigStore.fetch());
</script>

<template>
  <SettingsShell :is-loading="uiFlags.isFetching">
    <div class="flex flex-col gap-1">
      <SectionLayout
        :title="t('TEKOMI_SETTINGS.DEFAULT_MODEL.TITLE')"
        :description="t('TEKOMI_SETTINGS.DEFAULT_MODEL.DESCRIPTION')"
      >
        <div class="flex flex-col gap-3">
          <LlmDefaultModel
            :providers="llmProviders"
            :models="llmModels"
            :value="llmDefault"
            :is-saving="isSavingDefault"
            @save="saveDefaultModel"
          />

          <details class="px-4 py-3 border rounded-xl border-n-weak">
            <summary class="text-xs cursor-pointer text-n-slate-11">
              {{ t('TEKOMI_SETTINGS.RESOLUTION.TITLE') }}
            </summary>
            <p class="mt-2 text-xs text-n-slate-10">
              {{ t('TEKOMI_SETTINGS.RESOLUTION.DESCRIPTION') }}
            </p>
            <div class="grid gap-3 mt-3 sm:grid-cols-3">
              <div
                v-for="(tier, index) in TIERS"
                :key="tier"
                class="p-3 border rounded-lg border-n-weak"
              >
                <div class="flex items-center gap-2">
                  <span
                    class="flex items-center justify-center text-xs font-semibold text-white rounded-full size-5 bg-n-slate-12"
                  >
                    {{ index + 1 }}
                  </span>
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t(`TEKOMI_SETTINGS.RESOLUTION.${tier}.TITLE`) }}
                  </span>
                </div>
                <p class="mt-2 text-xs leading-relaxed text-n-slate-11">
                  {{ t(`TEKOMI_SETTINGS.RESOLUTION.${tier}.DESCRIPTION`) }}
                </p>
              </div>
            </div>
          </details>
        </div>
      </SectionLayout>

      <SectionLayout
        v-if="llmFeatureModels.length"
        :title="t('TEKOMI_SETTINGS.FEATURE_MODELS.TITLE')"
        :description="t('TEKOMI_SETTINGS.FEATURE_MODELS.DESCRIPTION')"
      >
        <div class="flex flex-wrap items-start gap-4">
          <div class="flex-1 min-w-[16rem] max-w-[22rem]">
            <FeatureModelList
              :feature-models="llmFeatureModels"
              :selected-key="selectedKey"
              @select="key => (selectedKey = key)"
            />
          </div>

          <div v-if="selected" class="flex-[999] min-w-0">
            <FeatureModelForm
              :feature-model="selected"
              :draft="drafts[selectedKey]"
              :providers="llmProviders"
              :models="llmModels"
              :params-error="paramsErrors[selectedKey]"
              :is-saving="savingKeys[selectedKey]"
              @save="saveFeatureModel"
              @remove="removeFeatureModel"
            />
          </div>
        </div>
      </SectionLayout>
    </div>
  </SettingsShell>
</template>
