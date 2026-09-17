<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import {
  AGGREGATES,
  CALENDAR_FIELDS,
  GROUP_BY_FIELDS,
  VIEW_TYPES,
  normalizeFields,
} from './constants';
import { useDealFields } from './useDealFields';

const props = defineProps({
  view: { type: Object, required: true },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const { dealAttributes, fieldLabel } = useDealFields();
const isMenuOpen = ref(false);

const fields = computed(() =>
  normalizeFields(props.view, dealAttributes.value)
);
const settings = computed(() => props.view.settings || {});

const aggregateOptions = computed(() =>
  AGGREGATES.map(aggregate => ({
    value: aggregate,
    label: t(`DEALS.OPTIONS.AGGREGATES.${aggregate.toUpperCase()}`),
  }))
);
const groupByOptions = computed(() => [
  { value: '', label: t('DEALS.OPTIONS.NO_GROUPING') },
  ...GROUP_BY_FIELDS.map(field => ({
    value: field,
    label: t(`DEALS.FIELDS.${field.toUpperCase()}`),
  })),
]);
const openInOptions = computed(() => [
  { value: 'side_panel', label: t('DEALS.OPTIONS.OPEN_IN_PANEL') },
  { value: 'page', label: t('DEALS.OPTIONS.OPEN_IN_PAGE') },
]);
const calendarFieldOptions = computed(() =>
  CALENDAR_FIELDS.map(field => ({
    value: field,
    label: t(`DEALS.FIELDS.${field.toUpperCase()}`),
  }))
);

const labelFor = (options, value) =>
  options.find(option => option.value === value)?.label || '';

const updateFields = nextFields => emit('update', { fields: nextFields });

const toggleField = (key, visible) => {
  updateFields(
    fields.value.map(field => (field.key === key ? { ...field, visible } : field))
  );
};

const updateSetting = (key, value) => {
  emit('update', { settings: { ...settings.value, [key]: value } });
};
</script>

<template>
  <div class="relative">
    <Button
      :label="t('DEALS.TOOLBAR.OPTIONS')"
      icon="i-lucide-sliders-horizontal"
      color="slate"
      size="sm"
      variant="ghost"
      :class="{ 'bg-n-alpha-2': isMenuOpen }"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute z-40 flex flex-col gap-4 p-4 mt-1 border top-full ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] border-n-weak w-72 rounded-xl"
    >
      <div
        v-if="view.viewType === VIEW_TYPES.KANBAN"
        class="flex flex-col gap-3"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm text-n-slate-12">
            {{ t('DEALS.OPTIONS.AGGREGATE') }}
          </span>
          <SelectMenu
            :model-value="settings.aggregate || 'sum'"
            :options="aggregateOptions"
            :label="labelFor(aggregateOptions, settings.aggregate || 'sum')"
            sub-menu-position="left"
            @update:model-value="updateSetting('aggregate', $event)"
          />
        </div>
        <label
          class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
        >
          <Checkbox
            :model-value="!!settings.hide_empty_columns"
            @update:model-value="updateSetting('hide_empty_columns', $event)"
          />
          {{ t('DEALS.OPTIONS.HIDE_EMPTY_COLUMNS') }}
        </label>
      </div>
      <div
        v-if="[VIEW_TYPES.TABLE, VIEW_TYPES.LIST].includes(view.viewType)"
        class="flex items-center justify-between gap-2"
      >
        <span class="text-sm text-n-slate-12">
          {{ t('DEALS.OPTIONS.GROUP_BY') }}
        </span>
        <SelectMenu
          :model-value="view.groupBy || ''"
          :options="groupByOptions"
          :label="labelFor(groupByOptions, view.groupBy || '')"
          sub-menu-position="left"
          @update:model-value="emit('update', { groupBy: $event || null })"
        />
      </div>
      <div
        v-if="view.viewType === VIEW_TYPES.CALENDAR"
        class="flex items-center justify-between gap-2"
      >
        <span class="text-sm text-n-slate-12">
          {{ t('DEALS.OPTIONS.CALENDAR_FIELD') }}
        </span>
        <SelectMenu
          :model-value="settings.calendar_field || 'expected_close_date'"
          :options="calendarFieldOptions"
          :label="
            labelFor(
              calendarFieldOptions,
              settings.calendar_field || 'expected_close_date'
            )
          "
          sub-menu-position="left"
          @update:model-value="updateSetting('calendar_field', $event)"
        />
      </div>
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('DEALS.OPTIONS.OPEN_IN') }}
        </span>
        <SelectMenu
          :model-value="settings.open_in || 'side_panel'"
          :options="openInOptions"
          :label="labelFor(openInOptions, settings.open_in || 'side_panel')"
          sub-menu-position="left"
          @update:model-value="updateSetting('open_in', $event)"
        />
      </div>
      <div class="flex flex-col gap-2">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('DEALS.OPTIONS.VISIBLE_FIELDS') }}
        </span>
        <Draggable
          :model-value="fields"
          item-key="key"
          handle=".field-handle"
          ghost-class="opacity-40"
          animation="150"
          class="flex flex-col gap-1"
          @update:model-value="updateFields"
        >
          <template #item="{ element }">
            <div class="flex items-center gap-2 py-1 text-sm text-n-slate-12">
              <Icon
                icon="i-lucide-grip-vertical"
                class="field-handle size-4 cursor-grab text-n-slate-10"
              />
              <Checkbox
                :model-value="element.visible"
                @update:model-value="toggleField(element.key, $event)"
              />
              {{ fieldLabel(element.key) }}
            </div>
          </template>
        </Draggable>
      </div>
    </div>
  </div>
</template>
