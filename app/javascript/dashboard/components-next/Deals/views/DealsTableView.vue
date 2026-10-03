<script setup>
import { ref, computed, toRef, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useElementSize,
  useEventListener,
  useIntersectionObserver,
  useScroll,
} from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DealFieldValue from '../DealFieldValue.vue';
import { useDealGroups } from '../useDealGroups';
import { useDealFields } from '../useDealFields';
import { DEFAULT_COLUMN_WIDTH, formatVND } from '../constants';

const props = defineProps({
  deals: { type: Array, required: true },
  stages: { type: Array, required: true },
  agents: { type: Array, required: true },
  fields: { type: Array, required: true },
  groupBy: { type: String, default: null },
  hasMore: { type: Boolean, default: false },
  isFetching: { type: Boolean, default: false },
  isFetchingMore: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update',
  'move',
  'delete',
  'loadMore',
  'updateFields',
  'open',
]);

const EDITABLE_FIELDS = [
  'name',
  'value',
  'stage',
  'assignee',
  'expected_close_date',
];
const NAME_COLUMN_WIDTH = 260;
const MIN_COLUMN_WIDTH = 96;
const ROW_HEIGHT = 40;
const OVERSCAN_ROWS = 8;

const { t } = useI18n();
const { fieldLabel } = useDealFields();
const sentinelRef = ref(null);
const scrollRef = ref(null);
const editingCell = ref(null);
const draftValue = ref('');
const selectedIds = ref([]);
const collapsedGroups = ref([]);
const bulkStageId = ref('');
const resizing = ref(null);
const liveWidths = ref({});

const stagesById = computed(() =>
  Object.fromEntries(props.stages.map(stage => [stage.id, stage]))
);
const columns = computed(() =>
  props.fields
    .filter(field => field.visible)
    .map(field => ({
      ...field,
      width: liveWidths.value[field.key] || field.width || DEFAULT_COLUMN_WIDTH,
    }))
);
const groups = useDealGroups(
  toRef(props, 'deals'),
  toRef(props, 'groupBy'),
  toRef(props, 'stages')
);
const stageOptions = computed(() =>
  props.stages.map(stage => ({ value: stage.id, label: stage.name }))
);
const agentOptions = computed(() => [
  { value: '', label: t('DEALS.UNASSIGNED') },
  ...props.agents.map(agent => ({ value: agent.id, label: agent.name })),
]);
const allSelected = computed(
  () =>
    props.deals.length > 0 && selectedIds.value.length === props.deals.length
);
const selectedDeals = computed(() =>
  props.deals.filter(deal => selectedIds.value.includes(deal.id))
);

const isEditing = (deal, field) =>
  editingCell.value?.dealId === deal.id && editingCell.value?.field === field;

const vFocus = { mounted: el => el.focus() };

const startEdit = (deal, field) => {
  if (!EDITABLE_FIELDS.includes(field) || isEditing(deal, field)) return;
  editingCell.value = { dealId: deal.id, field };
  draftValue.value = {
    name: deal.name,
    value: deal.value ?? '',
    stage: deal.stageId,
    assignee: deal.assignee?.id ?? '',
    expected_close_date: deal.expectedCloseDate || '',
  }[field];
};

const cancelEdit = () => {
  editingCell.value = null;
};

const commitEdit = deal => {
  if (!editingCell.value) return;
  const { field } = editingCell.value;
  const value = draftValue.value;
  editingCell.value = null;

  if (field === 'stage') {
    if (value !== deal.stageId) emit('move', { deal, stageId: Number(value) });
    return;
  }
  const changes = {
    name: () => (value.trim() ? { name: value.trim() } : null),
    value: () => ({ value: value === '' ? null : Number(value) }),
    assignee: () => ({ assigneeId: value === '' ? null : Number(value) }),
    expected_close_date: () => ({ expectedCloseDate: value || null }),
  }[field]();
  if (changes) emit('update', { deal, changes });
};

const toggleAll = checked => {
  selectedIds.value = checked ? props.deals.map(deal => deal.id) : [];
};

const toggleDeal = (deal, checked) => {
  selectedIds.value = checked
    ? [...selectedIds.value, deal.id]
    : selectedIds.value.filter(id => id !== deal.id);
};

const toggleGroup = key => {
  collapsedGroups.value = collapsedGroups.value.includes(key)
    ? collapsedGroups.value.filter(groupKey => groupKey !== key)
    : [...collapsedGroups.value, key];
};

const moveSelected = () => {
  selectedDeals.value.forEach(deal => {
    if (deal.stageId !== Number(bulkStageId.value)) {
      emit('move', { deal, stageId: Number(bulkStageId.value) });
    }
  });
  bulkStageId.value = '';
};

const deleteSelected = () => {
  emit('delete', selectedDeals.value);
  selectedIds.value = [];
};

const groupTotal = group =>
  formatVND(group.deals.reduce((total, deal) => total + (deal.value || 0), 0));

const startResize = (event, column) => {
  resizing.value = { key: column.key, startX: event.clientX, width: column.width };
};

useEventListener(window, 'mousemove', event => {
  if (!resizing.value) return;
  const { key, startX, width } = resizing.value;
  liveWidths.value = {
    ...liveWidths.value,
    [key]: Math.max(MIN_COLUMN_WIDTH, width + event.clientX - startX),
  };
});

useEventListener(window, 'mouseup', () => {
  if (!resizing.value) return;
  resizing.value = null;
  emit(
    'updateFields',
    props.fields.map(field => ({
      ...field,
      width: liveWidths.value[field.key] || field.width,
    }))
  );
});

watch(
  () => props.fields,
  () => {
    liveWidths.value = {};
  }
);

watch(
  () => props.deals,
  deals => {
    const ids = deals.map(deal => deal.id);
    selectedIds.value = selectedIds.value.filter(id => ids.includes(id));
  }
);

const { y: scrollTop } = useScroll(scrollRef);
const { height: viewportHeight } = useElementSize(scrollRef);

// Groups and their rows are flattened so the whole table can be windowed as one list.
const rows = computed(() =>
  groups.value.flatMap(group => [
    ...(props.groupBy ? [{ type: 'group', key: group.key, group }] : []),
    ...(collapsedGroups.value.includes(group.key)
      ? []
      : group.deals.map(deal => ({ type: 'deal', key: `deal-${deal.id}`, deal }))),
  ])
);

const startIndex = computed(() =>
  Math.max(0, Math.floor(scrollTop.value / ROW_HEIGHT) - OVERSCAN_ROWS)
);

const endIndex = computed(() =>
  Math.min(
    rows.value.length,
    Math.ceil((scrollTop.value + viewportHeight.value) / ROW_HEIGHT) +
      OVERSCAN_ROWS
  )
);

const visibleRows = computed(() =>
  rows.value.slice(startIndex.value, endIndex.value)
);

const topSpacerHeight = computed(() => startIndex.value * ROW_HEIGHT);

const bottomSpacerHeight = computed(
  () => (rows.value.length - endIndex.value) * ROW_HEIGHT
);

useIntersectionObserver(sentinelRef, ([entry]) => {
  if (entry?.isIntersecting && props.hasMore && !props.isFetchingMore) {
    emit('loadMore');
  }
});
</script>

<template>
  <div class="flex flex-col h-full min-h-0 px-6 pb-6">
    <div
      v-if="selectedIds.length"
      class="flex items-center gap-3 px-3 py-2 mb-2 text-sm rounded-lg bg-n-alpha-2"
    >
      <span class="text-n-slate-12">
        {{ t('DEALS.TABLE.SELECTED', { count: selectedIds.length }) }}
      </span>
      <Select
        v-model="bulkStageId"
        :options="stageOptions"
        :placeholder="t('DEALS.TABLE.MOVE_TO_STAGE')"
        @update:model-value="moveSelected"
      />
      <Button
        :label="t('DEALS.TABLE.DELETE_SELECTED')"
        icon="i-lucide-trash"
        color="ruby"
        variant="ghost"
        size="sm"
        @click="deleteSelected"
      />
    </div>
    <div v-if="isFetching" class="flex justify-center py-10">
      <Spinner />
    </div>
    <div
      v-else
      ref="scrollRef"
      class="flex-1 min-h-0 overflow-auto border rounded-lg border-n-weak"
    >
      <table class="text-sm border-collapse table-fixed w-max min-w-full">
        <thead class="sticky top-0 z-10 bg-n-solid-2">
          <tr class="border-b border-n-weak">
            <th class="w-10 px-3 py-2">
              <Checkbox
                :model-value="allSelected"
                :indeterminate="!!selectedIds.length && !allSelected"
                @update:model-value="toggleAll"
              />
            </th>
            <th
              class="px-3 py-2 font-medium text-start text-n-slate-11"
              :style="{ width: `${NAME_COLUMN_WIDTH}px` }"
            >
              {{ t('DEALS.FIELDS.NAME') }}
            </th>
            <th
              v-for="column in columns"
              :key="column.key"
              class="relative px-3 py-2 font-medium text-start text-n-slate-11"
              :style="{ width: `${column.width}px` }"
            >
              <span class="block truncate">
                {{ fieldLabel(column.key) }}
              </span>
              <span
                class="absolute top-0 bottom-0 w-1.5 cursor-col-resize ltr:right-0 rtl:left-0 hover:bg-n-brand"
                @mousedown.prevent="startResize($event, column)"
              />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="topSpacerHeight" :style="{ height: `${topSpacerHeight}px` }">
            <td :colspan="columns.length + 2" />
          </tr>
          <template v-for="row in visibleRows" :key="row.key">
            <tr
              v-if="row.type === 'group'"
              class="cursor-pointer bg-n-alpha-1"
              :style="{ height: `${ROW_HEIGHT}px` }"
              @click="toggleGroup(row.group.key)"
            >
              <td :colspan="columns.length + 2" class="px-3 py-2">
                <span class="flex items-center gap-2 font-medium text-n-slate-12">
                  <Icon
                    :icon="
                      collapsedGroups.includes(row.group.key)
                        ? 'i-lucide-chevron-right'
                        : 'i-lucide-chevron-down'
                    "
                    class="size-4"
                  />
                  <span
                    v-if="row.group.color"
                    class="rounded-sm size-2"
                    :style="{ backgroundColor: row.group.color }"
                  />
                  {{ row.group.label }}
                  <span class="font-normal text-n-slate-11">
                    {{ row.group.deals.length }} · {{ groupTotal(row.group) }}
                  </span>
                </span>
              </td>
            </tr>
              <tr
                v-else
                class="border-b border-n-weak hover:bg-n-alpha-1"
                :style="{ height: `${ROW_HEIGHT}px` }"
              >
                <td class="px-3 py-2">
                  <Checkbox
                    :model-value="selectedIds.includes(row.deal.id)"
                    @update:model-value="toggleDeal(row.deal, $event)"
                  />
                </td>
                <td
                  class="px-3 py-2 truncate cursor-text text-n-slate-12"
                  @click="startEdit(row.deal, 'name')"
                >
                  <input
                    v-if="isEditing(row.deal, 'name')"
                    v-model="draftValue"
                    class="w-full px-1 py-0.5 mb-0 text-sm rounded reset-base bg-n-alpha-2"
                    v-focus
                    @blur="commitEdit(row.deal)"
                    @keydown.enter="commitEdit(row.deal)"
                    @keydown.esc="cancelEdit"
                  />
                  <span v-else class="flex items-center gap-1 group/name">
                    <span class="font-medium truncate">{{ row.deal.name }}</span>
                    <Button
                      icon="i-lucide-panel-right-open"
                      color="slate"
                      variant="ghost"
                      size="xs"
                      class="invisible flex-shrink-0 ltr:ml-auto rtl:mr-auto group-hover/name:visible"
                      @click.stop="emit('open', row.deal)"
                    />
                  </span>
                </td>
                <td
                  v-for="column in columns"
                  :key="column.key"
                  class="px-3 py-2 text-n-slate-11"
                  @click="startEdit(row.deal, column.key)"
                >
                  <input
                    v-if="
                      isEditing(row.deal, column.key) &&
                      ['value', 'expected_close_date'].includes(column.key)
                    "
                    v-model="draftValue"
                    :type="column.key === 'value' ? 'number' : 'date'"
                    min="0"
                    class="w-full px-1 py-0.5 mb-0 text-sm rounded reset-base bg-n-alpha-2"
                    v-focus
                    @blur="commitEdit(row.deal)"
                    @keydown.enter="commitEdit(row.deal)"
                    @keydown.esc="cancelEdit"
                  />
                  <select
                    v-else-if="
                      isEditing(row.deal, column.key) &&
                      ['stage', 'assignee'].includes(column.key)
                    "
                    v-model="draftValue"
                    class="w-full px-1 py-0.5 mb-0 text-sm rounded reset-base bg-n-alpha-2"
                    v-focus
                    @change="commitEdit(row.deal)"
                    @blur="cancelEdit"
                    @keydown.esc="cancelEdit"
                  >
                    <option
                      v-for="option in column.key === 'stage'
                        ? stageOptions
                        : agentOptions"
                      :key="option.value"
                      :value="option.value"
                    >
                      {{ option.label }}
                    </option>
                  </select>
                  <DealFieldValue
                    v-else
                    :deal="row.deal"
                    :field="column.key"
                    :stage="stagesById[row.deal.stageId]"
                  />
                </td>
              </tr>
          </template>
          <tr
            v-if="bottomSpacerHeight"
            :style="{ height: `${bottomSpacerHeight}px` }"
          >
            <td :colspan="columns.length + 2" />
          </tr>
        </tbody>
      </table>
      <p
        v-if="!deals.length"
        class="py-10 text-sm text-center text-n-slate-11"
      >
        {{ t('DEALS.EMPTY_STATE') }}
      </p>
      <div ref="sentinelRef" class="flex justify-center h-8">
        <Spinner v-if="isFetchingMore" :size="16" />
      </div>
    </div>
  </div>
</template>
