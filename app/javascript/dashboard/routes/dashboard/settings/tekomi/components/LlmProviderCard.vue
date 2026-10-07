<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  provider: {
    type: Object,
    required: true,
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['save', 'remove']);

const { t } = useI18n();

const apiKey = ref('');
const apiBase = ref(props.provider.api_base || '');

watch(
  () => props.provider,
  provider => {
    apiBase.value = provider.api_base || '';
  }
);

const canSave = computed(() =>
  props.provider.requires_api_base
    ? Boolean(apiBase.value.trim())
    : Boolean(apiKey.value.trim())
);

const badge = computed(() => {
  if (!props.provider.configured) {
    return t('TEKOMI_SETTINGS.LLM_PROVIDERS.NOT_CONFIGURED');
  }

  return t('TEKOMI_SETTINGS.LLM_PROVIDERS.TENANT_KEY', {
    key: props.provider.masked_api_key || props.provider.api_base,
  });
});

const save = () => {
  if (!canSave.value) return;

  emit('save', {
    provider: props.provider,
    apiKey: apiKey.value.trim(),
    apiBase: apiBase.value.trim(),
  });
  apiKey.value = '';
};
</script>

<template>
  <div class="grid gap-3 p-4 border rounded-xl border-n-weak">
    <div class="flex items-start justify-between gap-4">
      <div>
        <p class="text-sm font-medium text-n-slate-12">
          {{ provider.name }}
        </p>
        <p class="text-xs text-n-slate-10">
          {{ provider.provider_type }}
        </p>
      </div>
      <span
        class="px-2 py-1 text-xs font-medium rounded-lg shrink-0"
        :class="
          provider.configured
            ? 'bg-n-teal-3 text-n-teal-11'
            : 'bg-n-slate-3 text-n-slate-11'
        "
      >
        {{ badge }}
      </span>
    </div>
    <input
      v-if="provider.supports_api_base"
      v-model="apiBase"
      type="text"
      spellcheck="false"
      :placeholder="t('TEKOMI_SETTINGS.LLM_PROVIDERS.API_BASE_PLACEHOLDER')"
      class="w-full px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
    />
    <div class="flex flex-col gap-2 sm:flex-row">
      <input
        v-model="apiKey"
        type="password"
        autocomplete="new-password"
        :placeholder="
          provider.configured
            ? t('TEKOMI_SETTINGS.LLM_PROVIDERS.REPLACE_PLACEHOLDER')
            : t('TEKOMI_SETTINGS.LLM_PROVIDERS.KEY_PLACEHOLDER')
        "
        class="w-full px-3 py-2 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
        @keyup.enter="save"
      />
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="isSaving || !canSave"
        @click="save"
      >
        {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.SAVE') }}
      </button>
      <button
        v-if="provider.configured"
        type="button"
        class="px-4 py-2 text-sm font-medium border rounded-lg border-n-weak text-n-slate-11 disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="isSaving"
        @click="emit('remove', provider)"
      >
        {{ t('TEKOMI_SETTINGS.LLM_PROVIDERS.REMOVE') }}
      </button>
    </div>
  </div>
</template>
