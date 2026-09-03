<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import LiveReportsAPI from 'dashboard/api/liveReports';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import { useAsyncBlock } from '../composables/useAsyncBlock';

const { t } = useI18n();

const { data, isLoading, hasError, load } = useAsyncBlock(async () => {
  const response = await LiveReportsAPI.getConversationMetric();
  return response.data;
});

// `open` and `pending` are the only two disjoint buckets in this payload --
// `unattended` and `unassigned` are both subsets of `open`, not additional
// slices of the same pie. Summing all four here would double-count and
// mislabel the total, so the donut (and this total) only ever combines
// `open` and `pending`; the two subsets are rendered as "of which" lines
// beside it instead of arcs.
const total = computed(
  () => (data.value?.open ?? 0) + (data.value?.pending ?? 0)
);

const openDash = computed(() => {
  if (!total.value) return '0 100';
  return `${((data.value.open / total.value) * 100).toFixed(1)} 100`;
});

onMounted(load);
</script>

<template>
  <CardLayout>
    <div class="flex items-center justify-between w-full">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('HOME.ACCOUNT.TITLE') }}
      </h2>
      <span class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11">
        {{ t('HOME.ACCOUNT.ADMIN') }}
      </span>
    </div>

    <div
      v-if="isLoading"
      class="w-full h-28 rounded bg-n-alpha-2 animate-pulse"
    />

    <button
      v-else-if="hasError"
      class="self-start text-xs text-n-brand hover:underline"
      @click="load"
    >
      {{ t('HOME.RETRY') }}
    </button>

    <div v-else class="flex items-center w-full gap-4">
      <svg viewBox="0 0 42 42" class="-rotate-90 size-24 shrink-0">
        <circle
          cx="21"
          cy="21"
          r="15.9"
          fill="none"
          stroke-width="4"
          class="stroke-n-alpha-2"
        />
        <circle
          cx="21"
          cy="21"
          r="15.9"
          fill="none"
          stroke-width="4"
          stroke="currentColor"
          :stroke-dasharray="openDash"
          class="text-n-brand"
        />
      </svg>
      <div class="flex flex-col gap-1 text-xs min-w-0">
        <p class="text-base font-medium text-n-slate-12">{{ total }}</p>
        <p class="text-n-slate-11">
          {{ t('HOME.ACCOUNT.OPEN', { count: data?.open ?? 0 }) }}
        </p>
        <p class="text-n-slate-11">
          {{ t('HOME.ACCOUNT.PENDING', { count: data?.pending ?? 0 }) }}
        </p>
        <p class="text-n-slate-10">
          {{ t('HOME.ACCOUNT.UNATTENDED', { count: data?.unattended ?? 0 }) }}
        </p>
        <p class="text-n-slate-10">
          {{ t('HOME.ACCOUNT.UNASSIGNED', { count: data?.unassigned ?? 0 }) }}
        </p>
      </div>
    </div>
  </CardLayout>
</template>
