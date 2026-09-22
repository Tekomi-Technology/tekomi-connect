<script setup>
import { toRef } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TicketFieldValue from './TicketFieldValue.vue';
import { useTicketFields } from './useTicketFields';
import { useSlaCountdown } from './useSlaCountdown';

const props = defineProps({
  ticket: { type: Object, required: true },
  fields: { type: Array, required: true },
  stagesById: { type: Object, required: true },
});

const { fieldLabel } = useTicketFields();
const { style } = useSlaCountdown(toRef(props, 'ticket'));

const FIELD_ICONS = {
  sla: 'i-lucide-timer',
  stage: 'i-lucide-flag',
  assignee: 'i-lucide-user-round',
  contact: 'i-lucide-contact',
  created_by: 'i-lucide-sparkles',
  created_at: 'i-lucide-clock',
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 text-sm border rounded-lg shadow-sm cursor-grab bg-n-solid-2 hover:border-n-slate-6"
    :class="style?.card || 'border-n-weak'"
  >
    <span class="font-medium truncate text-n-slate-12">{{ ticket.title }}</span>
    <div
      v-for="field in fields"
      :key="field"
      v-tooltip.left="fieldLabel(field)"
      class="flex items-center min-w-0 gap-2 text-n-slate-11"
    >
      <Icon
        :icon="FIELD_ICONS[field] || 'i-lucide-tag'"
        class="flex-shrink-0 size-3.5"
      />
      <TicketFieldValue
        :ticket="ticket"
        :field="field"
        :stage="stagesById[ticket.stageId]"
      />
    </div>
  </div>
</template>
