<script setup>
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DealFieldValue from './DealFieldValue.vue';

defineProps({
  deal: { type: Object, required: true },
  fields: { type: Array, required: true },
  stagesById: { type: Object, required: true },
});

const FIELD_ICONS = {
  value: 'i-lucide-banknote',
  stage: 'i-lucide-flag',
  assignee: 'i-lucide-user-round',
  contact: 'i-lucide-contact',
  expected_close_date: 'i-lucide-calendar',
  created_at: 'i-lucide-clock',
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 text-sm border rounded-lg shadow-sm cursor-grab bg-n-solid-2 border-n-weak hover:border-n-slate-6"
  >
    <span class="font-medium truncate text-n-slate-12">{{ deal.name }}</span>
    <div
      v-for="field in fields"
      :key="field"
      class="flex items-center min-w-0 gap-2 text-n-slate-11"
    >
      <Icon
        :icon="FIELD_ICONS[field] || 'i-lucide-tag'"
        class="flex-shrink-0 size-3.5"
      />
      <DealFieldValue
        :deal="deal"
        :field="field"
        :stage="stagesById[deal.stageId]"
      />
    </div>
  </div>
</template>
