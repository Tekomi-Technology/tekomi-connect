<script setup>
import { toRef } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useSlaCountdown } from './useSlaCountdown';

const props = defineProps({
  ticket: { type: Object, required: true },
  stage: { type: Object, default: null },
});

defineEmits(['open']);

const { hasSla, isOverdue, label, style } = useSlaCountdown(
  toRef(props, 'ticket')
);
</script>

<template>
  <div class="flex items-center gap-2 p-2 text-sm rounded-lg bg-n-alpha-1">
    <button
      type="button"
      class="flex flex-col flex-1 min-w-0 gap-0.5 text-start"
      @click="$emit('open')"
    >
      <span class="font-medium truncate text-n-slate-12">
        {{ ticket.title }}
      </span>
      <span class="flex items-center gap-1.5 truncate text-n-slate-11">
        <span
          v-if="stage"
          class="flex-shrink-0 rounded-sm size-2"
          :style="{ backgroundColor: stage.color }"
        />
        {{ stage?.name }}
        <template v-if="hasSla">
          <Icon
            v-if="style"
            :icon="style.icon"
            class="flex-shrink-0 size-3"
            :class="style.text"
          />
          <span :class="style?.text">
            {{
              isOverdue
                ? $t('TICKETS.SLA.OVERDUE_BY', { duration: label })
                : $t('TICKETS.SLA.DUE_IN', { duration: label })
            }}
          </span>
        </template>
      </span>
    </button>
    <slot />
  </div>
</template>
