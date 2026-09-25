<script setup>
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { INTEREST_BADGE_CLASSES } from 'dashboard/components-next/ConversationAnalysis/constants';

defineProps({
  opportunities: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['openConversation']);

const { t } = useI18n();

const DETAIL_FIELDS = [
  { section: 'customer', prefix: 'CUSTOMER', key: 'needs' },
  { section: 'customer', prefix: 'CUSTOMER', key: 'budget' },
  { section: 'customer', prefix: 'CUSTOMER', key: 'timeline' },
  { section: 'insight', prefix: 'INSIGHT', key: 'barriers' },
];
</script>

<template>
  <div class="flex flex-col gap-3">
    <p v-if="!opportunities.length" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_ANALYSIS.OPPORTUNITIES.EMPTY') }}
    </p>
    <button
      v-for="item in opportunities"
      :key="item.id"
      type="button"
      class="flex flex-col gap-3 p-4 text-left rounded-xl bg-n-solid-2 hover:bg-n-alpha-2"
      @click="emit('openConversation', item.conversation_id)"
    >
      <span class="flex items-center justify-between gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ item.contact.name }} · #{{ item.conversation_id }}
        </span>
        <span class="flex items-center gap-2 shrink-0">
          <span class="text-xs text-n-slate-10">
            {{ dynamicTime(item.updated_at) }}
          </span>
          <span
            class="px-2 py-0.5 text-xs rounded-md"
            :class="INTEREST_BADGE_CLASSES[item.insight.interest_level]"
          >
            {{
              t(
                `CONVERSATION_ANALYSIS.INSIGHT.INTEREST_LEVELS.${item.insight.interest_level.toUpperCase()}`
              )
            }}
          </span>
        </span>
      </span>
      <span v-if="item.insight?.summary" class="text-sm text-n-slate-12">
        {{ item.insight.summary }}
      </span>
      <span class="grid grid-cols-1 gap-2 md:grid-cols-2">
        <template v-for="field in DETAIL_FIELDS" :key="field.key">
          <span
            v-if="item[field.section]?.[field.key]"
            class="flex flex-col gap-0.5"
          >
            <span class="text-xs text-n-slate-11">
              {{
                t(
                  `CONVERSATION_ANALYSIS.${field.prefix}.FIELDS.${field.key.toUpperCase()}`
                )
              }}
            </span>
            <span class="text-sm text-n-slate-12">
              {{ item[field.section][field.key] }}
            </span>
          </span>
        </template>
      </span>
      <span
        v-if="item.care?.next_action"
        class="flex flex-col gap-0.5 p-2 rounded-lg bg-n-alpha-2"
      >
        <span class="text-xs text-n-slate-11">
          {{ t('CONVERSATION_ANALYSIS.CARE.FIELDS.NEXT_ACTION') }}
          <template v-if="item.care.contact_timing">
            · {{ item.care.contact_timing }}
          </template>
        </span>
        <span class="text-sm text-n-slate-12">
          {{ item.care.next_action }}
        </span>
      </span>
      <span v-if="item.assignee.name" class="text-xs text-n-slate-10">
        {{
          t('CONVERSATION_ANALYSIS.OPPORTUNITIES.ASSIGNEE', {
            name: item.assignee.name,
          })
        }}
      </span>
    </button>
  </div>
</template>
