<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import { SORT_FIELDS } from './constants';

const props = defineProps({
  sorts: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:sorts']);

const { t } = useI18n();
const isMenuOpen = ref(false);

const fieldOptions = computed(() => [
  { label: t('DEALS.SORT.MANUAL'), value: '' },
  ...SORT_FIELDS.map(field => ({
    label: t(`DEALS.FIELDS.${field.toUpperCase()}`),
    value: field,
  })),
]);

const directionOptions = computed(() => [
  { label: t('DEALS.SORT.ASC'), value: 'asc' },
  { label: t('DEALS.SORT.DESC'), value: 'desc' },
]);

const activeField = computed(() => props.sorts[0]?.field || '');
const activeDirection = computed(() => props.sorts[0]?.direction || 'asc');

const labelFor = (options, value) =>
  options.find(option => option.value === value)?.label;

const updateSort = (field, direction) => {
  emit('update:sorts', field ? [{ field, direction }] : []);
};
</script>

<template>
  <div class="relative">
    <Button
      :label="t('DEALS.TOOLBAR.SORT')"
      icon="i-lucide-arrow-down-up"
      color="slate"
      size="sm"
      variant="ghost"
      :class="{ 'bg-n-alpha-2': isMenuOpen || activeField }"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute z-40 top-full mt-1 ltr:right-0 rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">{{ t('DEALS.SORT.FIELD') }}</span>
        <SelectMenu
          :model-value="activeField"
          :options="fieldOptions"
          :label="labelFor(fieldOptions, activeField)"
          sub-menu-position="left"
          @update:model-value="updateSort($event, activeDirection)"
        />
      </div>
      <div v-if="activeField" class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('DEALS.SORT.DIRECTION') }}
        </span>
        <SelectMenu
          :model-value="activeDirection"
          :options="directionOptions"
          :label="labelFor(directionOptions, activeDirection)"
          sub-menu-position="left"
          @update:model-value="updateSort(activeField, $event)"
        />
      </div>
    </div>
  </div>
</template>
