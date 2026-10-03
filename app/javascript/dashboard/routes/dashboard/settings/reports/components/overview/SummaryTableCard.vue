<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatTime } from '@chatwoot/utils';
import Button from 'dashboard/components-next/button/Button.vue';
import MetricCard from './MetricCard.vue';

const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  icon: { type: String, default: '' },
  nameLabel: { type: String, required: true },
  rows: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  limit: { type: Number, default: 6 },
});

defineEmits(['download']);

const { t } = useI18n();
const key = 'OVERVIEW_REPORTS.SUMMARY';

const ranked = computed(() =>
  [...props.rows]
    .filter(row => row.conversationsCount > 0)
    .sort((a, b) => b.conversationsCount - a.conversationsCount)
    .slice(0, props.limit)
);

const topCount = computed(() => ranked.value[0]?.conversationsCount || 0);

const share = row =>
  topCount.value ? Math.round((row.conversationsCount / topCount.value) * 100) : 0;

const resolvedRate = row =>
  row.conversationsCount
    ? `${Math.round((row.resolvedConversationsCount / row.conversationsCount) * 100)}%`
    : '—';
</script>

<template>
  <MetricCard
    :header="title"
    :description="description"
    :icon="icon"
    :show-live-badge="false"
    :is-loading="isLoading"
    :loading-message="t(`${key}.LOADING`)"
    body-class="w-full min-w-0"
  >
    <template #control>
      <Button
        v-tooltip="t(`${key}.DOWNLOAD`)"
        sm
        slate
        faded
        icon="i-lucide-download"
        class="rounded-md"
        @click="$emit('download')"
      />
    </template>
    <p v-if="!ranked.length" class="py-6 text-sm text-center text-n-slate-11">
      {{ t(`${key}.EMPTY`) }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="border-b border-n-weak">
          <th
            class="py-2 pr-3 text-[11px] font-medium tracking-wide text-left uppercase text-n-slate-11"
          >
            {{ nameLabel }}
          </th>
          <th
            class="px-3 py-2 text-[11px] font-medium tracking-wide text-right uppercase text-n-slate-11"
          >
            {{ t(`${key}.CONVERSATIONS`) }}
          </th>
          <th
            class="hidden px-3 py-2 text-[11px] font-medium tracking-wide text-left uppercase text-n-slate-11 lg:table-cell"
          >
            {{ t(`${key}.SHARE`) }}
          </th>
          <th
            class="px-3 py-2 text-[11px] font-medium tracking-wide text-right uppercase text-n-slate-11"
          >
            {{ t(`${key}.RESOLVED`) }}
          </th>
          <th
            class="py-2 pl-3 text-[11px] font-medium tracking-wide text-right uppercase text-n-slate-11"
          >
            {{ t(`${key}.FIRST_RESPONSE`) }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in ranked"
          :key="row.id"
          class="border-b border-n-strong/20 last:border-b-0"
        >
          <td class="py-2.5 pr-3 truncate text-n-slate-12 max-w-[12rem]">
            {{ row.name || t(`${key}.UNKNOWN`) }}
          </td>
          <td
            class="px-3 py-2.5 font-medium text-right tabular-nums text-n-slate-12"
          >
            {{ row.conversationsCount }}
          </td>
          <td class="hidden px-3 py-2.5 lg:table-cell">
            <span class="block w-full h-1.5 rounded-full bg-n-alpha-2">
              <span
                class="block h-full rounded-full bg-n-brand"
                :style="{ width: `${share(row)}%` }"
              />
            </span>
          </td>
          <td class="px-3 py-2.5 text-right tabular-nums text-n-slate-11">
            {{ resolvedRate(row) }}
          </td>
          <td class="py-2.5 pl-3 text-right tabular-nums text-n-slate-11">
            {{
              row.avgFirstResponseTime
                ? formatTime(row.avgFirstResponseTime)
                : '—'
            }}
          </td>
        </tr>
      </tbody>
    </table>
  </MetricCard>
</template>
