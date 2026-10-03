<script setup>
import { computed, toRef } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useTicketFields } from './useTicketFields';
import { useSlaCountdown } from './useSlaCountdown';
import {
  customAttributeKey,
  formatTicketDate,
  CREATED_BY_ICONS,
} from './constants';

const props = defineProps({
  ticket: { type: Object, required: true },
  field: { type: String, required: true },
  stage: { type: Object, default: null },
});

const { findAttribute } = useTicketFields();
const { hasSla, isOverdue, label, style } = useSlaCountdown(
  toRef(props, 'ticket')
);

const customValue = computed(() => {
  const key = customAttributeKey(props.field);
  if (!key) return null;
  const value = props.ticket.customAttributes?.[key];
  if (value === undefined || value === null || value === '') return '';
  const displayType = findAttribute(props.field)?.attributeDisplayType;
  if (displayType === 'date') return formatTicketDate(value);
  if (displayType === 'checkbox') return value ? '✓' : '✗';
  return String(value);
});
</script>

<template>
  <span class="flex items-center min-w-0 gap-1.5 truncate">
    <template v-if="field === 'sla'">
      <template v-if="hasSla">
        <Icon
          v-if="style"
          :icon="style.icon"
          class="flex-shrink-0 size-3.5"
          :class="style.text"
        />
        <span class="truncate" :class="style?.text">
          {{
            isOverdue
              ? $t('TICKETS.SLA.OVERDUE_BY', { duration: label })
              : $t('TICKETS.SLA.DUE_IN', { duration: label })
          }}
        </span>
      </template>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('TICKETS.SLA.NONE') }}
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
      <template v-if="ticket.assignee">
        <Avatar
          :name="ticket.assignee.name"
          :src="ticket.assignee.thumbnail"
          :size="16"
          rounded-full
        />
        <span class="truncate">{{ ticket.assignee.name }}</span>
      </template>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('TICKETS.UNASSIGNED') }}
      </span>
    </template>
    <template v-else-if="field === 'contact'">
      <template v-if="ticket.contact">
        <Avatar
          :name="ticket.contact.name"
          :src="ticket.contact.thumbnail"
          :size="16"
          rounded-full
        />
        <span class="truncate">{{ ticket.contact.name }}</span>
      </template>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('TICKETS.NO_CONTACT') }}
      </span>
    </template>
    <template v-else-if="field === 'created_by'">
      <Icon
        :icon="CREATED_BY_ICONS[ticket.createdBy]"
        class="flex-shrink-0 size-3.5"
      />
      <span class="truncate">
        {{ $t(`TICKETS.CREATED_BY.${ticket.createdBy.toUpperCase()}`) }}
      </span>
    </template>
    <span v-else-if="field === 'created_at'" class="truncate">
      {{ formatTicketDate(ticket.createdAt) }}
    </span>
    <template v-else-if="customValue !== null">
      <span v-if="customValue" class="truncate">{{ customValue }}</span>
      <span v-else class="truncate text-n-slate-10">
        {{ $t('TICKETS.NO_VALUE') }}
      </span>
    </template>
  </span>
</template>
