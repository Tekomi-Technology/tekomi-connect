<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  providers: {
    type: Array,
    required: true,
  },
  usage: {
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

const editingType = ref('');
const apiKey = ref('');
const apiBase = ref('');

const startEditing = provider => {
  editingType.value = provider.provider_type;
  apiKey.value = '';
  apiBase.value = provider.api_base || '';
};

const cancelEditing = () => {
  editingType.value = '';
  apiKey.value = '';
  apiBase.value = '';
};

const canSave = provider =>
  provider.requires_api_base ? apiBase.value.trim() : apiKey.value.trim();

const save = provider => {
  if (!canSave(provider)) return;
  emit('save', {
    provider,
    apiKey: apiKey.value.trim(),
    apiBase: apiBase.value.trim(),
  });
  cancelEditing();
};

const usageLabel = provider => {
  const count = props.usage[provider.provider_type] || 0;
  if (props.usage.default === provider.provider_type) {
    return t('TEKOMI_SETTINGS.LLM_PROVIDERS.USAGE_DEFAULT', { count });
  }
  if (count) {
    return t('TEKOMI_SETTINGS.LLM_PROVIDERS.USAGE_FEATURES', { count });
  }
  return '—';
};
</script>

<template>
  <div class="overflow-x-auto">
    <table class="w-full text-sm border-collapse">
      <thead>
        <tr class="text-left bg-n-alpha-1">
          <th class="px-4 py-2 text-xs font-medium text-n-slate-11">
            {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.COL_PROVIDER') }}
          </th>
          <th class="px-4 py-2 text-xs font-medium text-n-slate-11">
            {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.COL_STATUS') }}
          </th>
          <th class="px-4 py-2 text-xs font-medium text-n-slate-11">
            {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.COL_USAGE') }}
          </th>
          <th class="px-4 py-2" />
        </tr>
      </thead>
      <tbody>
        <template v-for="provider in providers" :key="provider.provider_type">
          <tr class="border-t border-n-weak">
            <td class="px-4 py-3 font-medium text-n-slate-12">
              {{ provider.name }}
            </td>
            <td class="px-4 py-3">
              <span
                class="px-2 py-1 text-xs font-medium rounded-lg"
                :class="
                  provider.configured
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{
                  provider.configured
                    ? provider.masked_api_key || provider.api_base
                    : t('TEKOMI_SETTINGS.LLM_PROVIDERS.NOT_CONFIGURED')
                }}
              </span>
            </td>
            <td class="px-4 py-3 text-xs text-n-slate-11">
              {{ usageLabel(provider) }}
            </td>
            <td class="px-4 py-3 text-right">
              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  class="px-3 py-1.5 text-xs font-medium border rounded-lg border-n-weak text-n-slate-12"
                  @click="
                    editingType === provider.provider_type
                      ? cancelEditing()
                      : startEditing(provider)
                  "
                >
                  {{
                    provider.configured
                      ? t('TEKOMI_SETTINGS.LLM_PROVIDERS.EDIT')
                      : t('TEKOMI_SETTINGS.LLM_PROVIDERS.ADD')
                  }}
                </button>
                <button
                  v-if="provider.configured"
                  type="button"
                  class="px-3 py-1.5 text-xs font-medium border rounded-lg border-n-weak text-n-slate-11 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="savingKeys[provider.provider_type]"
                  @click="emit('remove', provider)"
                >
                  {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.REMOVE') }}
                </button>
              </div>
            </td>
          </tr>

          <tr
            v-if="editingType === provider.provider_type"
            class="border-t border-n-weak bg-n-alpha-1"
          >
            <td colspan="4" class="px-4 py-4">
              <div class="flex flex-wrap items-end gap-3">
                <label class="flex flex-col flex-1 gap-1.5 min-w-[14rem]">
                  <span class="text-xs font-medium text-n-slate-11">
                    {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.KEY_LABEL') }}
                  </span>
                  <input
                    v-model="apiKey"
                    type="password"
                    autocomplete="new-password"
                    :placeholder="
                      provider.configured
                        ? t('TEKOMI_SETTINGS.LLM_PROVIDERS.REPLACE_PLACEHOLDER')
                        : t('TEKOMI_SETTINGS.LLM_PROVIDERS.KEY_PLACEHOLDER')
                    "
                    class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
                    @keyup.enter="save(provider)"
                  />
                </label>

                <label
                  v-if="provider.supports_api_base"
                  class="flex flex-col flex-1 gap-1.5 min-w-[14rem]"
                >
                  <span class="text-xs font-medium text-n-slate-11">
                    {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.API_BASE_LABEL') }}
                  </span>
                  <input
                    v-model="apiBase"
                    type="text"
                    spellcheck="false"
                    :placeholder="
                      t('TEKOMI_SETTINGS.LLM_PROVIDERS.API_BASE_PLACEHOLDER')
                    "
                    class="px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
                  />
                </label>

                <div class="flex gap-2">
                  <button
                    type="button"
                    class="px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="
                      savingKeys[provider.provider_type] || !canSave(provider)
                    "
                    @click="save(provider)"
                  >
                    {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.SAVE') }}
                  </button>
                  <button
                    type="button"
                    class="px-4 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-11"
                    @click="cancelEditing"
                  >
                    {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.CANCEL') }}
                  </button>
                </div>
              </div>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>
