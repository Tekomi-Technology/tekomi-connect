<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useTekomi } from 'dashboard/composables/useTekomi';
import { useConfig } from 'dashboard/composables/useConfig';
import { useTekomiConfigStore } from 'dashboard/store/tekomi/preferences';
import { useAiAlertsStore } from 'dashboard/stores/aiAlerts';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import FeatureToggle from './components/FeatureToggle.vue';
import LlmDefaultModel from './components/LlmDefaultModel.vue';
import LlmProviderCard from './components/LlmProviderCard.vue';
import LlmFeatureModels from './components/LlmFeatureModels.vue';
import TekomiPaywall from 'next/tekomi/pageComponents/Paywall.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const { t } = useI18n();
const { tekomiEnabled } = useTekomi();
const { isEnterprise } = useConfig();
const { isOnChatwootCloud, accountId } = useAccount();
const { isAdmin } = useAdmin();
const route = useRoute();
const router = useRouter();

const tekomiConfigStore = useTekomiConfigStore();
const aiAlertsStore = useAiAlertsStore();
const {
  uiFlags,
  llmProviders,
  llmPrompts,
  llmServices,
  llmDefault,
  llmFeatureModels,
  llmModels,
} = storeToRefs(tekomiConfigStore);
const { meta: aiAlertsMeta } = storeToRefs(aiAlertsStore);
const savingProviders = reactive({});
const savingPrompts = reactive({});
const savingFeatureModels = reactive({});
const isSavingDefault = ref(false);

const isLoading = computed(() => uiFlags.value.isFetching);

const tabs = computed(() => [
  { key: 'settings', label: t('TEKOMI_SETTINGS.TABS.SETTINGS') },
  {
    key: 'alerts',
    label: t('TEKOMI_SETTINGS.TABS.ALERTS'),
    count: aiAlertsMeta.value.unreadCount,
  },
]);

const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab =>
    tab.key === 'alerts'
      ? route.name === 'tekomi_ai_alerts'
      : route.name === 'tekomi_settings_index'
  )
);

const onTabChanged = tab => {
  router.push({
    name: tab.key === 'alerts' ? 'tekomi_ai_alerts' : 'tekomi_settings_index',
    params: { accountId: accountId.value },
  });
};

const featureToggles = computed(() => [
  {
    key: 'label_suggestion',
  },
  {
    key: 'help_center_search',
    enterprise: true,
  },
  {
    key: 'audio_transcription',
    enterprise: true,
  },
]);

const shouldShowFeature = feature => {
  // Cloud will always see these features as long as tekomi is enabled
  if (isOnChatwootCloud.value && tekomiEnabled) {
    return true;
  }

  if (feature.enterprise) {
    // if the app is in enterprise mode, then we can show the feature
    // this is not the installation plan, but when the enterprise folder is missing
    return isEnterprise;
  }

  return true;
};

const isFeatureAccessible = feature => {
  // Cloud will always see these features as long as tekomi is enabled
  if (isOnChatwootCloud.value && tekomiEnabled) {
    return true;
  }

  if (feature.enterprise) {
    return isEnterprise;
  }

  return true;
};

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

function promptTitle(prompt) {
  return prompt.key.replace(/_/g, ' ');
}

async function savePrompt(prompt) {
  savingPrompts[prompt.key] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      tekomi_prompts: { [prompt.key]: prompt.body },
    });
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.SAVE_ERROR'));
  } finally {
    savingPrompts[prompt.key] = false;
  }
}

async function restorePrompt(prompt) {
  savingPrompts[prompt.key] = true;
  try {
    await tekomiConfigStore.updatePreferences({
      tekomi_prompts: { [prompt.key]: '' },
    });
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.RESTORE_SUCCESS'));
  } catch (error) {
    useAlert(t('TEKOMI_SETTINGS.PROMPTS.SAVE_ERROR'));
  } finally {
    savingPrompts[prompt.key] = false;
  }
}

onMounted(() => {
  tekomiConfigStore.fetch();
  if (isAdmin.value) aiAlertsStore.fetch({ limit: 1 });
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :no-records-message="t('TEKOMI_SETTINGS.NOT_ENABLED')"
    :loading-message="t('TEKOMI_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TEKOMI_SETTINGS.TITLE')"
        :description="t('TEKOMI_SETTINGS.DESCRIPTION')"
        :link-text="t('TEKOMI_SETTINGS.LINK_TEXT')"
        icon-name="tekomi"
        feature-name="tekomi_billing"
      >
        <template #tabs>
          <TabBar
            v-if="isAdmin"
            :tabs="tabs"
            :initial-active-tab="activeTabIndex"
            @tab-changed="onTabChanged"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div v-if="tekomiEnabled" class="flex flex-col gap-1">
        <!-- Features Section -->
        <SectionLayout
          :title="t('TEKOMI_SETTINGS.FEATURES.TITLE')"
          :description="t('TEKOMI_SETTINGS.FEATURES.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <FeatureToggle
              v-for="feature in featureToggles"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              @change="handleFeatureToggle"
            />
          </div>
        </SectionLayout>

        <SectionLayout
          v-if="isAdmin"
          :title="t('TEKOMI_SETTINGS.LLM_PROVIDERS.TITLE')"
          :description="t('TEKOMI_SETTINGS.LLM_PROVIDERS.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <LlmProviderCard
              v-for="provider in llmProviders"
              :key="provider.provider_type"
              :provider="provider"
              :is-saving="savingProviders[provider.provider_type]"
              @save="saveProvider"
              @remove="removeProvider"
            />
          </div>
        </SectionLayout>

        <SectionLayout
          v-if="isAdmin && llmServices.length"
          :title="t('TEKOMI_SETTINGS.LLM_SERVICES.TITLE')"
          :description="t('TEKOMI_SETTINGS.LLM_SERVICES.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <LlmProviderCard
              v-for="service in llmServices"
              :key="service.provider_type"
              :provider="service"
              :is-saving="savingProviders[service.provider_type]"
              @save="saveProvider"
              @remove="removeProvider"
            />
          </div>
        </SectionLayout>

        <SectionLayout
          v-if="isAdmin"
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
          v-if="isAdmin && llmFeatureModels.length"
          :title="t('TEKOMI_SETTINGS.FEATURE_MODELS.TITLE')"
          :description="t('TEKOMI_SETTINGS.FEATURE_MODELS.DESCRIPTION')"
        >
          <LlmFeatureModels
            :feature-models="llmFeatureModels"
            :providers="llmProviders"
            :saving-keys="savingFeatureModels"
            @save="saveFeatureModel"
            @remove="removeFeatureModel"
          />
        </SectionLayout>

        <SectionLayout
          v-if="isAdmin && llmPrompts.length"
          :title="t('TEKOMI_SETTINGS.PROMPTS.TITLE')"
          :description="t('TEKOMI_SETTINGS.PROMPTS.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <div
              v-for="prompt in llmPrompts"
              :key="prompt.key"
              class="grid gap-3 p-4 border rounded-xl border-n-weak"
            >
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="text-sm font-medium text-n-slate-12">
                    {{ prompt.name || promptTitle(prompt) }}
                  </p>
                  <p class="text-xs text-n-slate-10">
                    {{ prompt.description || prompt.group }}
                  </p>
                </div>
                <span
                  class="px-2 py-1 text-xs font-medium rounded-lg"
                  :class="
                    prompt.customized
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-slate-3 text-n-slate-11'
                  "
                >
                  {{
                    prompt.customized
                      ? t('TEKOMI_SETTINGS.PROMPTS.CUSTOMIZED')
                      : t('TEKOMI_SETTINGS.PROMPTS.DEFAULT')
                  }}
                </span>
              </div>
              <textarea
                v-model="prompt.body"
                rows="12"
                spellcheck="false"
                class="w-full px-3 py-2 font-mono text-xs bg-transparent border rounded-lg resize-y border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
              />
              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="savingPrompts[prompt.key]"
                  @click="savePrompt(prompt)"
                >
                  {{ t('TEKOMI_SETTINGS.PROMPTS.SAVE') }}
                </button>
                <button
                  v-if="prompt.customized"
                  type="button"
                  class="px-4 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-11 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="savingPrompts[prompt.key]"
                  @click="restorePrompt(prompt)"
                >
                  {{ t('TEKOMI_SETTINGS.PROMPTS.RESTORE') }}
                </button>
              </div>
              <details>
                <summary class="text-xs cursor-pointer text-n-slate-10">
                  {{ t('TEKOMI_SETTINGS.PROMPTS.SHOW_DEFAULT') }}
                </summary>
                <pre class="p-3 mt-2 overflow-x-auto text-xs whitespace-pre-wrap rounded-lg bg-n-slate-2 text-n-slate-11">{{ prompt.default_body }}</pre>
              </details>
            </div>
          </div>
        </SectionLayout>
      </div>
      <div v-else>
        <TekomiPaywall />
      </div>
    </template>
  </SettingsLayout>
</template>
