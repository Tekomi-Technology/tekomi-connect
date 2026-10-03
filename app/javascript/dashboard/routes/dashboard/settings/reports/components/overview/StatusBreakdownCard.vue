<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import MetricCard from './MetricCard.vue';
import { CONVERSATION_STATUSES, STATUS_BAR_CLASS } from '../../constants';

const props = defineProps({
  rows: { type: Array, default: () => [] },
  totals: { type: Object, default: null },
  dimension: { type: String, default: 'inbox' },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['update:dimension']);

const { t } = useI18n();
const key = 'OVERVIEW_REPORTS.SUMMARY';

const [showDropdown, toggleDropdown] = useToggle();

const dimensionItems = computed(() =>
  ['inbox', 'assignee'].map(value => ({
    label: t(`${key}.DIMENSION.${value.toUpperCase()}`),
    value,
  }))
);

const dimensionLabel = computed(
  () => t(`${key}.SPLIT_BY`, { name: t(`${key}.DIMENSION.${props.dimension.toUpperCase()}`) })
);

const selectDimension = ({ value }) => {
  toggleDropdown(false);
  emit('update:dimension', value);
};

const segments = row =>
  CONVERSATION_STATUSES.filter(status => row[status] > 0).map(status => ({
    status,
    width: `${(row[status] / row.total) * 100}%`,
  }));
</script>

<template>
  <MetricCard
    :header="t(`${key}.BREAKDOWN.TITLE`)"
    :description="t(`${key}.BREAKDOWN.DESCRIPTION`)"
    icon="i-lucide-table-2"
    :show-live-badge="false"
    :is-loading="isLoading"
    :loading-message="t(`${key}.LOADING`)"
    body-class="w-full min-w-0 overflow-x-auto"
  >
    <template #control>
      <div
        v-on-clickaway="() => toggleDropdown(false)"
        class="relative flex items-center"
      >
        <Button
          sm
          slate
          faded
          :label="dimensionLabel"
          class="rounded-md"
          @click="toggleDropdown()"
        />
        <DropdownMenu
          v-if="showDropdown"
          :menu-items="dimensionItems"
          class="mt-1 ltr:right-0 rtl:left-0 top-full"
          @action="selectDimension($event)"
        />
      </div>
    </template>
    <p v-if="!rows.length" class="py-6 text-sm text-center text-n-slate-11">
      {{ t(`${key}.EMPTY`) }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="border-b border-n-weak">
          <th
            class="py-2 pr-3 text-[11px] font-medium tracking-wide text-left uppercase text-n-slate-11"
          >
            {{ t(`${key}.DIMENSION.${dimension.toUpperCase()}`) }}
          </th>
          <th
            v-for="status in CONVERSATION_STATUSES"
            :key="status"
            class="px-3 py-2 text-[11px] font-medium tracking-wide text-right uppercase text-n-slate-11"
          >
            {{ t(`${key}.STATUS.${status.toUpperCase()}`) }}
          </th>
          <th
            class="px-3 py-2 text-[11px] font-medium tracking-wide text-right uppercase text-n-slate-11"
          >
            {{ t(`${key}.TOTAL`) }}
          </th>
          <th
            class="hidden py-2 pl-3 text-[11px] font-medium tracking-wide text-left uppercase text-n-slate-11 lg:table-cell"
          >
            {{ t(`${key}.SPLIT`) }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="row.id ?? 'none'"
          class="border-b border-n-strong/20"
        >
          <td class="py-2.5 pr-3 truncate text-n-slate-12 max-w-[14rem]">
            {{ row.name || t(`${key}.UNASSIGNED`) }}
          </td>
          <td
            v-for="status in CONVERSATION_STATUSES"
            :key="status"
            class="px-3 py-2.5 text-right tabular-nums text-n-slate-11"
          >
            {{ row[status] }}
          </td>
          <td
            class="px-3 py-2.5 font-medium text-right tabular-nums text-n-slate-12"
          >
            {{ row.total }}
          </td>
          <td class="hidden py-2.5 pl-3 lg:table-cell">
            <span
              class="flex w-full h-1.5 overflow-hidden rounded-full bg-n-alpha-2"
            >
              <span
                v-for="segment in segments(row)"
                :key="segment.status"
                class="h-full"
                :class="STATUS_BAR_CLASS[segment.status]"
                :style="{ width: segment.width }"
              />
            </span>
          </td>
        </tr>
        <tr v-if="totals" class="bg-n-alpha-1">
          <td class="py-2.5 pr-3 font-semibold text-n-slate-12">
            {{ t(`${key}.TOTAL`) }}
          </td>
          <td
            v-for="status in CONVERSATION_STATUSES"
            :key="status"
            class="px-3 py-2.5 font-semibold text-right tabular-nums text-n-slate-12"
          >
            {{ totals[status] }}
          </td>
          <td
            class="px-3 py-2.5 font-semibold text-right tabular-nums text-n-slate-12"
          >
            {{ totals.total }}
          </td>
          <td class="hidden lg:table-cell" />
        </tr>
      </tbody>
    </table>
  </MetricCard>
</template>
