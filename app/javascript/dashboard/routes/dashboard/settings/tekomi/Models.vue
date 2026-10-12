<script setup>
import { onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';

import SettingsShell from './SettingsShell.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import LlmDefaultModel from './components/LlmDefaultModel.vue';
import LlmFeatureModelTable from './components/LlmFeatureModelTable.vue';

const { t } = useI18n();

const tekomiConfigStore = useTekomiConfigStore();
const { uiFlags, llmProviders, llmDefault, llmFeatureModels, llmModels } =
  storeToRefs(tekomiConfigStore);

const savingFeatureModels = reactive({});
const isSavingDefault = ref(false);

const tiers = [
  { key: 'OVERRIDE' },
  { key: 'FIXED' },
  { key: 'DEFAULT' },
];

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

async function saveFeatureModel({ featureKey, payload }) {
  savingFeatureModels[featureKey] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      llm_feature_models: { [featureKey]: payload },
    });
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE_ERROR'));
  } finally {
    savingFeatureModels[featureKey] = false;
  }
}

async function removeFeatureModel({ featureKey }) {
  savingFeatureModels[featureKey] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      llm_feature_models: { [featureKey]: { remove: true } },
    });
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.RESTORE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.FEATURE_MODELS.SAVE_ERROR'));
  } finally {
    savingFeatureModels[featureKey] = false;
  }
}

onMounted(() => tekomiConfigStore.fetch());
</script>

<template>
  <SettingsShell :is-loading="uiFlags.isFetching">
    <div class="flex flex-col gap-1">
      <SectionLayout
        :title="t('TEKOMI_SETTINGS.RESOLUTION.TITLE')"
        :description="t('TEKOMI_SETTINGS.RESOLUTION.DESCRIPTION')"
      >
        <div class="grid gap-3 sm:grid-cols-3">
          <div
            v-for="(tier, index) in tiers"
            :key="tier.key"
            class="p-4 border rounded-xl border-n-weak"
          >
            <div class="flex items-center gap-2">
              <span
                class="flex items-center justify-center text-xs font-semibold text-white rounded-full size-5 bg-n-slate-12"
              >
                {{ index + 1 }}
              </span>
              <span class="text-sm font-medium text-n-slate-12">
                {{ t(`TEKOMI_SETTINGS.RESOLUTION.${tier.key}.TITLE`) }}
              </span>
            </div>
            <p class="mt-2 text-xs leading-relaxed text-n-slate-11">
              {{ t(`TEKOMI_SETTINGS.RESOLUTION.${tier.key}.DESCRIPTION`) }}
            </p>
          </div>
        </div>
      </SectionLayout>

      <SectionLayout
        :title="t('TEKOMI_SETTINGS.DEFAULT_MODEL.TITLE')"
        :description="t('TEKOMI_SETTINGS.DEFAULT_MODEL.DESCRIPTION')"
      >
        <LlmDefaultModel
          :providers="llmProviders"
          :models="llmModels"
          :value="llmDefault"
          :is-saving="isSavingDefault"
          @save="saveDefaultModel"
        />
      </SectionLayout>

      <SectionLayout
        v-if="llmFeatureModels.length"
        :title="t('TEKOMI_SETTINGS.FEATURE_MODELS.TITLE')"
        :description="t('TEKOMI_SETTINGS.FEATURE_MODELS.DESCRIPTION')"
      >
        <div class="flex flex-col gap-3">
          <div class="overflow-hidden border rounded-xl border-n-weak">
            <LlmFeatureModelTable
              :feature-models="llmFeatureModels"
              :providers="llmProviders"
              :models="llmModels"
              :saving-keys="savingFeatureModels"
              @save="saveFeatureModel"
              @remove="removeFeatureModel"
            />
          </div>
          <p
            class="px-4 py-3 text-xs leading-relaxed border rounded-xl border-n-amber-6 bg-n-amber-2 text-n-amber-12"
          >
            {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.FIXED_NOTE') }}
          </p>
        </div>
      </SectionLayout>
    </div>
  </SettingsShell>
</template>
