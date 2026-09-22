<script setup>
import { computed } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useDealFields } from './useDealFields';
import { customAttributeKey, formatVND, formatDealDate } from './constants';

const props = defineProps({
  deal: { type: Object, required: true },
  field: { type: String, required: true },
  stage: { type: Object, default: null },
});

const { findAttribute } = useDealFields();

const customValue = computed(() => {
  const key = customAttributeKey(props.field);
  if (!key) return null;
  const value = props.deal.customAttributes?.[key];
  if (value === undefined || value === null || value === '') return '';
  const displayType = findAttribute(props.field)?.attributeDisplayType;
  if (displayType === 'date') return formatDealDate(value);
  if (displayType === 'checkbox') return value ? '✓' : '✗';
  return String(value);
});
</script>

<template>
  <span class="flex items-center min-w-0 gap-1.5 truncate">
    <template v-if="field === 'value'">
      <span v-if="deal.value !== null" class="truncate text-n-slate-12">
        {{ formatVND(deal.value) }}
      </span>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('DEALS.NO_VALUE') }}
      </span>
    </template>
    <template v-else-if="field === 'stage' && stage">
      <span
        class="flex-shrink-0 rounded-sm size-2"
        :style="{ backgroundColor: stage.color }"
      />
      <span class="truncate">{{ stage.name }}</span>
    </template>
    <template v-else-if="field === 'assignee'">
      <template v-if="deal.assignee">
        <Avatar
          :name="deal.assignee.name"
          :src="deal.assignee.thumbnail"
          :size="16"
          rounded-full
        />
        <span class="truncate">{{ deal.assignee.name }}</span>
      </template>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('DEALS.UNASSIGNED') }}
      </span>
    </template>
    <template v-else-if="field === 'contact'">
      <template v-if="deal.contact">
        <Avatar
          :name="deal.contact.name"
          :src="deal.contact.thumbnail"
          :size="16"
          rounded-full
        />
        <span class="truncate">{{ deal.contact.name }}</span>
      </template>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('DEALS.NO_CONTACT') }}
      </span>
    </template>
    <template v-else-if="field === 'expected_close_date'">
      <span v-if="deal.expectedCloseDate" class="truncate">
        {{ formatDealDate(deal.expectedCloseDate) }}
      </span>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('DEALS.NO_DATE') }}
      </span>
    </template>
    <span v-else-if="field === 'created_at'" class="truncate">
      {{ formatDealDate(deal.createdAt) }}
    </span>
    <template v-else-if="customValue !== null">
      <span v-if="customValue" class="truncate">{{ customValue }}</span>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('DEALS.NO_VALUE') }}
      </span>
    </template>
  </span>
</template>
