<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  featureModels: {
    type: Array,
    required: true,
  },
  selectedKey: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const search = ref('');
const activeStatus = ref('all');
const activeGroup = ref('');

const groupLabel = group =>
  t(`TEKOMI_SETTINGS.GROUPS.${group.toUpperCase()}`, group);

const customizedCount = computed(
  () => props.featureModels.filter(featureModel => featureModel.customized).length
);

const statusFilters = computed(() => [
  {
    key: 'all',
    label: t('TEKOMI_SETTINGS.FEATURE_MODELS.FILTER_ALL', {
      count: props.featureModels.length,
    }),
  },
  {
    key: 'customized',
    label: t('TEKOMI_SETTINGS.FEATURE_MODELS.FILTER_CUSTOMIZED', {
      count: customizedCount.value,
    }),
  },
  {
    key: 'inherited',
    label: t('TEKOMI_SETTINGS.FEATURE_MODELS.FILTER_INHERITED', {
      count: props.featureModels.length - customizedCount.value,
    }),
  },
]);

const groupFilters = computed(() => {
  const counts = new Map();
  props.featureModels.forEach(featureModel => {
    counts.set(featureModel.group, (counts.get(featureModel.group) || 0) + 1);
  });
  return [...counts].map(([group, count]) => ({
    group,
    label: `${groupLabel(group)} ${count}`,
  }));
});

const matchesStatus = featureModel => {
  if (activeStatus.value === 'customized') return featureModel.customized;
  if (activeStatus.value === 'inherited') return !featureModel.customized;
  return true;
};

const filtered = computed(() => {
  const term = search.value.trim().toLowerCase();
  return props.featureModels.filter(featureModel => {
    if (!matchesStatus(featureModel)) return false;
    if (activeGroup.value && featureModel.group !== activeGroup.value) {
      return false;
    }
    if (!term) return true;
    return (
      featureModel.name.toLowerCase().includes(term) ||
      featureModel.feature_key.toLowerCase().includes(term) ||
      (featureModel.description || '').toLowerCase().includes(term)
    );
  });
});

const metaFor = featureModel =>
  featureModel.customized
    ? `${groupLabel(featureModel.group)} · ${featureModel.model}`
    : `${groupLabel(featureModel.group)} · ${t('TEKOMI_SETTINGS.FEATURE_MODELS.INHERITED')}`;
</script>

<template>
  <div
    class="flex flex-col overflow-hidden border rounded-xl border-n-weak bg-n-solid-1"
  >
    <div class="flex flex-col gap-3 p-3 border-b border-n-weak">
      <label class="flex flex-col gap-1.5">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.SEARCH_LABEL') }}
        </span>
        <span class="relative flex items-center">
          <Icon
            icon="i-lucide-search"
            class="absolute size-4 text-n-slate-10 left-3"
          />
          <input
            v-model="search"
            type="search"
            :placeholder="
              t('TEKOMI_SETTINGS.FEATURE_MODELS.SEARCH_PLACEHOLDER')
            "
            class="w-full py-2 pl-9 pr-3 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
          />
        </span>
      </label>

      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="filter in statusFilters"
          :key="filter.key"
          type="button"
          class="px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            activeStatus === filter.key
              ? 'border-n-brand bg-n-brand text-white'
              : 'border-n-weak text-n-slate-11'
          "
          @click="activeStatus = filter.key"
        >
          {{ filter.label }}
        </button>
      </div>

      <div class="flex flex-wrap gap-1.5">
        <button
          type="button"
          class="px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            activeGroup === ''
              ? 'border-n-slate-12 bg-n-slate-12 text-white'
              : 'border-n-weak text-n-slate-11'
          "
          @click="activeGroup = ''"
        >
          {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.ALL_GROUPS') }}
        </button>
        <button
          v-for="item in groupFilters"
          :key="item.group"
          type="button"
          class="px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            activeGroup === item.group
              ? 'border-n-slate-12 bg-n-slate-12 text-white'
              : 'border-n-weak text-n-slate-11'
          "
          @click="activeGroup = item.group"
        >
          {{ item.label }}
        </button>
      </div>
    </div>

    <ul class="flex flex-col gap-0.5 p-1.5 overflow-y-auto max-h-[34rem]">
      <li v-for="featureModel in filtered" :key="featureModel.feature_key">
        <button
          type="button"
          class="flex items-start w-full gap-2 px-2.5 py-2 text-left rounded-lg"
          :class="
            featureModel.feature_key === selectedKey
              ? 'bg-n-alpha-2 text-n-slate-12'
              : 'text-n-slate-12 hover:bg-n-alpha-1'
          "
          @click="emit('select', featureModel.feature_key)"
        >
          <span
            class="mt-1.5 rounded-full size-1.5 shrink-0"
            :class="featureModel.customized ? 'bg-n-teal-10' : 'bg-n-slate-6'"
          />
          <span class="min-w-0">
            <span class="block text-sm font-medium leading-tight">
              {{ featureModel.name }}
            </span>
            <span class="block mt-0.5 text-xs truncate text-n-slate-10">
              {{ metaFor(featureModel) }}
            </span>
          </span>
        </button>
      </li>
      <li
        v-if="!filtered.length"
        class="px-3 py-6 text-sm text-center text-n-slate-10"
      >
        {{ t('TEKOMI_SETTINGS.FEATURE_MODELS.NO_MATCH') }}
      </li>
    </ul>

    <div class="px-3 py-2.5 text-xs border-t border-n-weak text-n-slate-10">
      {{
        t('TEKOMI_SETTINGS.FEATURE_MODELS.LIST_SUMMARY', {
          shown: filtered.length,
          total: featureModels.length,
          customized: customizedCount,
        })
      }}
    </div>
  </div>
</template>
