<script setup>
import { computed } from 'vue';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DealCard from '../DealCard.vue';
import { formatVND, positionBetween } from '../constants';

const props = defineProps({
  deals: { type: Array, required: true },
  stages: { type: Array, required: true },
  fields: { type: Array, required: true },
  stageMeta: { type: Object, required: true },
  stageStats: { type: Array, required: true },
  settings: { type: Object, default: () => ({}) },
  isManualOrder: { type: Boolean, default: true },
  isFetching: { type: Boolean, default: false },
  fetchingStageId: { type: Number, default: null },
});

const emit = defineEmits(['move', 'create', 'loadMore', 'open']);

const aggregate = computed(() => props.settings.aggregate || 'sum');
const cardFields = computed(() =>
  props.fields.filter(field => field !== 'stage')
);
const stagesById = computed(() =>
  Object.fromEntries(props.stages.map(stage => [stage.id, stage]))
);
const statsByStage = computed(() =>
  Object.fromEntries(props.stageStats.map(stat => [stat.stageId, stat]))
);

const dealsInStage = stageId => {
  const stageDeals = props.deals.filter(deal => deal.stageId === stageId);
  if (!props.isManualOrder) return stageDeals;
  return [...stageDeals].sort((a, b) => a.position - b.position);
};

const columns = computed(() =>
  props.stages
    .map(stage => ({
      stage,
      deals: dealsInStage(stage.id),
      stat: statsByStage.value[stage.id],
    }))
    .filter(column => !props.settings.hide_empty_columns || column.stat?.count)
);

const aggregateLabel = stat => {
  if (!stat || aggregate.value === 'count') return '';
  return formatVND(stat[aggregate.value] ?? 0);
};

const onColumnChange = (column, { added, moved }) => {
  const change = added || moved;
  if (!change) return;
  const siblings = column.deals.filter(deal => deal.id !== change.element.id);
  const previous = siblings[change.newIndex - 1];
  const next = siblings[change.newIndex];
  emit('move', {
    deal: change.element,
    stageId: column.stage.id,
    afterId: previous?.id,
    position: positionBetween(previous?.position, next?.position),
  });
};
</script>

<template>
  <div class="flex h-full gap-3 px-6 pb-6 overflow-x-auto">
    <div v-if="isFetching" class="flex justify-center w-full py-10">
      <Spinner />
    </div>
    <template v-else>
      <section
        v-for="column in columns"
        :key="column.stage.id"
        class="flex flex-col flex-shrink-0 h-full min-h-0 w-72"
      >
        <header class="flex items-center gap-2 px-1 pb-2 text-sm">
          <span
            class="px-2 py-0.5 rounded-md font-medium text-n-slate-12 truncate"
            :style="{ backgroundColor: `${column.stage.color}33` }"
          >
            {{ column.stage.name }}
          </span>
          <span class="text-n-slate-11">{{ column.stat?.count || 0 }}</span>
          <span class="ltr:ml-auto rtl:mr-auto text-n-slate-11 truncate">
            {{ aggregateLabel(column.stat) }}
          </span>
        </header>
        <div
          class="flex flex-col flex-1 min-h-0 gap-2 p-2 overflow-y-auto rounded-xl bg-n-alpha-1"
        >
          <Draggable
            :model-value="column.deals"
            group="deals"
            item-key="id"
            ghost-class="opacity-40"
            animation="150"
            class="flex flex-col gap-2 min-h-12"
            @change="onColumnChange(column, $event)"
          >
            <template #item="{ element }">
              <DealCard
                :deal="element"
                :fields="cardFields"
                :stages-by-id="stagesById"
                @click="emit('open', element)"
              />
            </template>
          </Draggable>
          <Button
            v-if="stageMeta[column.stage.id]?.hasMore"
            :label="$t('DEALS.LOAD_MORE')"
            color="slate"
            variant="ghost"
            size="sm"
            :is-loading="fetchingStageId === column.stage.id"
            @click="emit('loadMore', column.stage.id)"
          />
          <Button
            :label="$t('DEALS.KANBAN.ADD')"
            icon="i-lucide-plus"
            color="slate"
            variant="ghost"
            size="sm"
            justify="start"
            @click="emit('create', { stageId: column.stage.id })"
          />
        </div>
      </section>
    </template>
  </div>
</template>
