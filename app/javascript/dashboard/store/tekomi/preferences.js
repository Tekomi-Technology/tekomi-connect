import { defineStore } from 'pinia';
import TekomiPreferencesAPI from 'dashboard/api/tekomi/preferences';

export const useTekomiConfigStore = defineStore('tekomiConfig', {
  state: () => ({
    features: {},
    llmProviders: [],
    llmServices: [],
    llmPrompts: [],
    llmDefault: { provider_type: null, model: null },
    llmFeatureModels: [],
    llmModels: {},
    uiFlags: {
      isFetching: false,
    },
  }),

  getters: {
    getFeatures: state => state.features,
    getUIFlags: state => state.uiFlags,
  },

  actions: {
    setPreferences(data) {
      this.features = data.features || {};
      this.llmProviders = data.llm_providers || [];
      this.llmServices = data.llm_services || [];
      this.llmPrompts = data.prompts || [];
      this.llmDefault = data.llm_default || {
        provider_type: null,
        model: null,
      };
      this.llmFeatureModels = data.llm_feature_models || [];
      this.llmModels = data.llm_models || {};
    },

    async fetch() {
      this.uiFlags.isFetching = true;
      try {
        const response = await TekomiPreferencesAPI.get();
        this.setPreferences(response.data);
      } catch (error) {
        // Ignore error
      } finally {
        this.uiFlags.isFetching = false;
      }
    },

    async updatePreferences(data) {
      const response = await TekomiPreferencesAPI.updatePreferences(data);
      this.setPreferences(response.data);
    },
  },
});
