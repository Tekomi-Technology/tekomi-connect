<script setup>
import { ref, computed, toRef } from 'vue';
import { useIntersectionObserver } from '@vueuse/core';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import DealFieldValue from '../DealFieldValue.vue';
import { useDealGroups } from '../useDealGroups';

const props = defineProps({
  deals: { type: Array, required: true },
  stages: { type: Array, required: true },
  fields: { type: Array, required: true },
  groupBy: { type: String, default: null },
  hasMore: { type: Boolean, default: false },
  isFetching: { type: Boolean, default: false },
  isFetchingMore: { type: Boolean, default: false },
});

const emit = defineEmits(['loadMore', 'open']);

const sentinelRef = ref(null);
const collapsedGroups = ref([]);

const stagesById = computed(() =>
  Object.fromEntries(props.stages.map(stage => [stage.id, stage]))
);
const groups = useDealGroups(
  toRef(props, 'deals'),
  toRef(props, 'groupBy'),
  toRef(props, 'stages')
);

const toggleGroup = key => {
  collapsedGroups.value = collapsedGroups.value.includes(key)
    ? collapsedGroups.value.filter(groupKey => groupKey !== key)
    : [...collapsedGroups.value, key];
};

useIntersectionObserver(sentinelRef, ([entry]) => {
  if (entry?.isIntersecting && props.hasMore && !props.isFetchingMore) {
    emit('loadMore');
  }
});
</script>

<template>
  <div class="flex flex-col h-full px-6 pb-6 overflow-y-auto">
    <div v-if="isFetching" class="flex justify-center py-10">
      <Spinner />
    </div>
    <p
      v-else-if="!deals.length"
      class="py-10 text-sm text-center text-n-slate-11"
    >
      {{ $t('DEALS.EMPTY_STATE') }}
    </p>
    <template v-else>
      <section v-for="group in groups" :key="group.key" class="flex flex-col">
        <button
          v-if="groupBy"
          type="button"
          class="flex items-center gap-2 py-2 text-sm font-medium text-start text-n-slate-12"
          @click="toggleGroup(group.key)"
        >
          <Icon
            :icon="
              collapsedGroups.includes(group.key)
                ? 'i-lucide-chevron-right'
                : 'i-lucide-chevron-down'
            "
            class="size-4"
          />
          <span
            v-if="group.color"
            class="rounded-sm size-2"
            :style="{ backgroundColor: group.color }"
          />
          {{ group.label }}
          <span class="font-normal text-n-slate-11">
            {{ group.deals.length }}
          </span>
        </button>
        <ul
          v-if="!collapsedGroups.includes(group.key)"
          class="flex flex-col list-none divide-y divide-n-weak"
        >
          <li
            v-for="deal in group.deals"
            :key="deal.id"
            class="flex flex-wrap items-center py-3 text-sm cursor-pointer gap-x-6 gap-y-1 hover:bg-n-alpha-1"
            @click="emit('open', deal)"
          >
            <span class="flex-1 font-medium truncate min-w-48 text-n-slate-12">
              {{ deal.name }}
            </span>
            <DealFieldValue
              v-for="field in fields"
              :key="field"
              :deal="deal"
              :field="field"
              :stage="stagesById[deal.stageId]"
              class="w-40 text-n-slate-11"
            />
          </li>
        </ul>
      </section>
    </template>
    <div ref="sentinelRef" class="flex justify-center h-8">
      <Spinner v-if="isFetchingMore" :size="16" />
    </div>
  </div>
</template>
