<script setup>
import { computed, onMounted, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import { useTekomi } from 'dashboard/composables/useTekomi';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';

import SettingsShell from './SettingsShell.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import FeatureToggle from './components/FeatureToggle.vue';
import LlmProviderTable from './components/LlmProviderTable.vue';

const { t } = useI18n();
const { tekomiEnabled } = useTekomi();
const { isEnterprise } = useConfig();
const { isOnChatwootCloud } = useAccount();

const tekomiConfigStore = useTekomiConfigStore();
const {
  uiFlags,
  llmProviders,
  llmServices,
  llmDefault,
  llmFeatureModels,
} = storeToRefs(tekomiConfigStore);

const savingProviders = reactive({});

const featureToggles = [
  { key: 'label_suggestion' },
  { key: 'help_center_search', enterprise: true },
  { key: 'audio_transcription', enterprise: true },
];

const isFeatureAccessible = feature => {
  if (isOnChatwootCloud.value && tekomiEnabled) return true;
  return feature.enterprise ? isEnterprise : true;
};

const providerUsage = computed(() => {
  const usage = { default: llmDefault.value.provider_type };
  llmFeatureModels.value.forEach(featureModel => {
    if (!featureModel.provider_type) return;
    usage[featureModel.provider_type] =
      (usage[featureModel.provider_type] || 0) + 1;
  });
  return usage;
});

async function handleFeatureToggle({ feature, enabled }) {
  try {
    await tekomiConfigStore.updatePreferences({
      tekomi_features: { [feature]: enabled },
    });
    useAlert(t('TEKOMI_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.API.ERROR'));
    tekomiConfigStore.fetch();
  }
}

async function saveProvider({ provider, apiKey, apiBase }) {
  const providerType = provider.provider_type;
  const payload = { provider_type: providerType };
  if (apiKey) payload.api_key = apiKey;
  if (provider.supports_api_base) payload.api_base = apiBase;

  savingProviders[providerType] = true;
  try {
    await tekomiConfigStore.updatePreferences({ llm_provider: payload });
    useAlert(t('TEKOMI_SETTINGS.LLM_PROVIDERS.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.LLM_PROVIDERS.SAVE_ERROR'));
  } finally {
    savingProviders[providerType] = false;
  }
}

async function removeProvider(provider) {
  const providerType = provider.provider_type;
  savingProviders[providerType] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      llm_provider: { provider_type: providerType, remove: true },
    });
    useAlert(t('TEKOMI_SETTINGS.LLM_PROVIDERS.REMOVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.LLM_PROVIDERS.SAVE_ERROR'));
  } finally {
    savingProviders[providerType] = false;
  }
}

onMounted(() => tekomiConfigStore.fetch());
</script>

<template>
  <SettingsShell :is-loading="uiFlags.isFetching">
    <div class="flex flex-col gap-1">
      <SectionLayout
        :title="t('TEKOMI_SETTINGS.LLM_PROVIDERS.TITLE')"
        :description="t('TEKOMI_SETTINGS.LLM_PROVIDERS.DESCRIPTION')"
      >
        <div class="overflow-hidden border rounded-xl border-n-weak">
          <LlmProviderTable
            :providers="llmProviders"
            :usage="providerUsage"
            :saving-keys="savingProviders"
            @save="saveProvider"
            @remove="removeProvider"
          />
        </div>
      </SectionLayout>

      <SectionLayout
        v-if="llmServices.length"
        :title="t('TEKOMI_SETTINGS.LLM_SERVICES.TITLE')"
        :description="t('TEKOMI_SETTINGS.LLM_SERVICES.DESCRIPTION')"
      >
        <div class="overflow-hidden border rounded-xl border-n-weak">
          <LlmProviderTable
            :providers="llmServices"
            :usage="{}"
            :saving-keys="savingProviders"
            @save="saveProvider"
            @remove="removeProvider"
          />
        </div>
      </SectionLayout>

      <SectionLayout
        :title="t('TEKOMI_SETTINGS.FEATURES.TITLE')"
        :description="t('TEKOMI_SETTINGS.FEATURES.DESCRIPTION')"
      >
        <div class="grid gap-4">
          <FeatureToggle
            v-for="feature in featureToggles"
            v-show="isFeatureAccessible(feature)"
            :key="feature.key"
            :is-allowed="isFeatureAccessible(feature)"
            :feature-key="feature.key"
            @change="handleFeatureToggle"
          />
        </div>
      </SectionLayout>
    </div>
  </SettingsShell>
</template>
