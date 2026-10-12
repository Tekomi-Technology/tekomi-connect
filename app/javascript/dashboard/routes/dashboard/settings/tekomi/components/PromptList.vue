<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  records: {
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
const activeGroup = ref('');

const groupLabel = group =>
  t(`TEKOMI_SETTINGS.GROUPS.${group.toUpperCase()}`, group);

const groups = computed(() => {
  const counts = new Map();
  props.records.forEach(record => {
    counts.set(record.group, (counts.get(record.group) || 0) + 1);
  });
  return [...counts].map(([group, count]) => ({
    group,
    label: `${groupLabel(group)} ${count}`,
  }));
});

const filtered = computed(() => {
  const term = search.value.trim().toLowerCase();
  return props.records.filter(record => {
    if (activeGroup.value && record.group !== activeGroup.value) return false;
    if (!term) return true;
    return (
      record.name.toLowerCase().includes(term) ||
      record.key.toLowerCase().includes(term) ||
      (record.description || '').toLowerCase().includes(term)
    );
  });
});

const customizedCount = computed(
  () => props.records.filter(record => record.customized).length
);
</script>

<template>
  <div
    class="flex flex-col overflow-hidden border rounded-xl border-n-weak bg-n-solid-1"
  >
    <div class="flex flex-col gap-3 p-3 border-b border-n-weak">
      <label class="flex flex-col gap-1.5">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('TEKOMI_SETTINGS.PROMPTS.SEARCH_LABEL') }}
        </span>
        <span class="relative flex items-center">
          <Icon
            icon="i-lucide-search"
            class="absolute size-4 text-n-slate-10 left-3"
          />
          <input
            v-model="search"
            type="search"
            :placeholder="t('TEKOMI_SETTINGS.PROMPTS.SEARCH_PLACEHOLDER')"
            class="w-full py-2 pl-9 pr-3 text-sm bg-transparent border rounded-lg border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand"
          />
        </span>
      </label>

      <div class="flex flex-wrap gap-1.5">
        <button
          type="button"
          class="px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            activeGroup === ''
              ? 'border-n-brand bg-n-brand text-white'
              : 'border-n-weak text-n-slate-11'
          "
          @click="activeGroup = ''"
        >
          {{ t('TEKOMI_SETTINGS.PROMPTS.ALL_GROUPS', { count: records.length }) }}
        </button>
        <button
          v-for="item in groups"
          :key="item.group"
          type="button"
          class="px-2.5 py-1 text-xs font-medium border rounded-full"
          :class="
            activeGroup === item.group
              ? 'border-n-brand bg-n-brand text-white'
              : 'border-n-weak text-n-slate-11'
          "
          @click="activeGroup = item.group"
        >
          {{ item.label }}
        </button>
      </div>
    </div>

    <ul class="flex flex-col gap-0.5 p-1.5 overflow-y-auto max-h-[32rem]">
      <li v-for="record in filtered" :key="record.key">
        <button
          type="button"
          class="flex items-start w-full gap-2 px-2.5 py-2 text-left rounded-lg"
          :class="
            record.key === selectedKey
              ? 'bg-n-alpha-2 text-n-slate-12'
              : 'text-n-slate-12 hover:bg-n-alpha-1'
          "
          @click="emit('select', record.key)"
        >
          <span
            class="mt-1.5 rounded-full size-1.5 shrink-0"
            :class="record.customized ? 'bg-n-teal-10' : 'bg-n-slate-6'"
          />
          <span class="min-w-0">
            <span class="block text-sm font-medium leading-tight">
              {{ record.name }}
            </span>
            <span class="block mt-0.5 text-xs text-n-slate-10">
              {{ groupLabel(record.group) }} ·
              {{ t('TEKOMI_SETTINGS.PROMPTS.LINE_COUNT', { count: record.lines }) }}
              <template v-if="record.customized">
                · {{ t('TEKOMI_SETTINGS.PROMPTS.CUSTOMIZED') }}
              </template>
            </span>
          </span>
        </button>
      </li>
      <li
        v-if="!filtered.length"
        class="px-3 py-6 text-sm text-center text-n-slate-10"
      >
        {{ t('TEKOMI_SETTINGS.PROMPTS.NO_MATCH') }}
      </li>
    </ul>

    <div class="px-3 py-2.5 text-xs border-t border-n-weak text-n-slate-10">
      {{
        t('TEKOMI_SETTINGS.PROMPTS.LIST_SUMMARY', {
          shown: filtered.length,
          total: records.length,
          customized: customizedCount,
        })
      }}
    </div>
  </div>
</template>
