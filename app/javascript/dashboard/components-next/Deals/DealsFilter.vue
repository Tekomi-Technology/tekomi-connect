<script setup>
import { useTemplateRef } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import ConditionRow from 'dashboard/components-next/filter/ConditionRow.vue';

defineProps({
  filterTypes: { type: Array, required: true },
});

const emit = defineEmits(['apply', 'close']);

const filters = defineModel({ type: Array, default: () => [] });

const DEFAULT_FILTER = {
  attributeKey: 'name',
  filterOperator: 'contains',
  values: '',
  queryOperator: 'and',
  attributeModel: 'standard',
};

const conditionsRef = useTemplateRef('conditionsRef');

const addFilter = () => {
  filters.value.push({ ...DEFAULT_FILTER });
};

const removeFilter = index => {
  filters.value.splice(index, 1);
  if (!filters.value.length) addFilter();
};

const clearFilters = () => {
  filters.value = [];
  emit('apply', []);
};

const applyFilters = () => {
  if (!conditionsRef.value.every(condition => condition.validate())) return;
  emit('apply', filters.value);
};

const outsideClickHandler = [
  () => emit('close'),
  { ignore: ['#toggleDealsFilterButton'] },
];
</script>

<template>
  <div
    v-on-click-outside="outsideClickHandler"
    class="z-40 w-[calc(100vw-2rem)] max-w-3xl lg:w-[750px] border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6"
  >
    <h3 class="text-base font-medium leading-6 text-n-slate-12">
      {{ $t('DEALS.FILTER.TITLE') }}
    </h3>
    <ul class="grid gap-4 list-none">
      <template v-for="(filter, index) in filters" :key="index">
        <ConditionRow
          v-if="index === 0"
          ref="conditionsRef"
          v-model:attribute-key="filter.attributeKey"
          v-model:filter-operator="filter.filterOperator"
          v-model:values="filter.values"
          :filter-types="filterTypes"
          @remove="removeFilter(index)"
        />
        <ConditionRow
          v-else
          ref="conditionsRef"
          v-model:attribute-key="filter.attributeKey"
          v-model:filter-operator="filter.filterOperator"
          v-model:query-operator="filters[index - 1].queryOperator"
          v-model:values="filter.values"
          show-query-operator
          :filter-types="filterTypes"
          @remove="removeFilter(index)"
        />
      </template>
    </ul>
    <div class="flex justify-between gap-2">
      <Button sm ghost blue class="flex-shrink-0" @click="addFilter">
        {{ $t('DEALS.FILTER.ADD_FILTER') }}
      </Button>
      <div class="flex gap-2 flex-shrink-0">
        <Button sm faded slate @click="clearFilters">
          {{ $t('DEALS.FILTER.CLEAR_FILTERS') }}
        </Button>
        <Button sm solid blue @click="applyFilters">
          {{ $t('DEALS.FILTER.APPLY_FILTERS') }}
        </Button>
      </div>
    </div>
  </div>
</template>
