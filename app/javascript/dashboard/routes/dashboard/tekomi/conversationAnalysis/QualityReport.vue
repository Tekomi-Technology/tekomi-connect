<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  QUALITY_CRITERIA,
  scoreTextClass,
} from 'dashboard/components-next/ConversationAnalysis/constants';

const props = defineProps({
  report: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['openConversation']);

const { t } = useI18n();

const criteria = computed(() =>
  QUALITY_CRITERIA.map(key => ({
    key,
    score: props.report.criteria?.[key],
  }))
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <div class="flex flex-col gap-1 p-4 rounded-xl bg-n-solid-2">
        <span class="text-xs text-n-slate-11">
          {{ t('CONVERSATION_ANALYSIS.REPORT.ANALYZED_COUNT') }}
        </span>
        <span class="text-2xl font-semibold text-n-slate-12">
          {{ report.analyzed_count }}
        </span>
      </div>
      <div class="flex flex-col gap-1 p-4 rounded-xl bg-n-solid-2">
        <span class="text-xs text-n-slate-11">
          {{ t('CONVERSATION_ANALYSIS.REPORT.AVERAGE_SCORE') }}
        </span>
        <span
          class="text-2xl font-semibold"
          :class="scoreTextClass(report.average_score)"
        >
          {{ report.average_score ?? '—' }}
        </span>
      </div>
      <div
        v-for="row in report.served_by"
        :key="row.served_by"
        class="flex flex-col gap-1 p-4 rounded-xl bg-n-solid-2"
      >
        <span class="text-xs text-n-slate-11">
          {{
            t(
              `CONVERSATION_ANALYSIS.QUALITY.SERVED_BY_OPTIONS.${row.served_by.toUpperCase()}`
            )
          }}
          ·
          {{ t('CONVERSATION_ANALYSIS.REPORT.COUNT', { count: row.count }) }}
        </span>
        <span
          class="text-2xl font-semibold"
          :class="scoreTextClass(row.average_score)"
        >
          {{ row.average_score ?? '—' }}
        </span>
      </div>
    </div>

    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.REPORT.CRITERIA') }}
      </h3>
      <div
        v-for="criterion in criteria"
        :key="criterion.key"
        class="grid items-center grid-cols-[12rem_1fr_3rem] gap-3"
      >
        <span class="text-sm text-n-slate-12 truncate">
          {{
            t(
              `CONVERSATION_ANALYSIS.QUALITY.CRITERIA.${criterion.key.toUpperCase()}`
            )
          }}
        </span>
        <progress
          :value="criterion.score || 0"
          max="5"
          class="w-full h-2 overflow-hidden rounded-full appearance-none bg-n-slate-3 [&::-webkit-progress-bar]:bg-n-slate-3 [&::-webkit-progress-value]:bg-n-brand [&::-moz-progress-bar]:bg-n-brand"
        />
        <span class="text-sm text-right text-n-slate-12">
          {{ criterion.score ?? '—' }}
        </span>
      </div>
    </section>

    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.REPORT.AGENTS') }}
      </h3>
      <p v-if="!report.agents.length" class="text-sm text-n-slate-11">
        {{ t('CONVERSATION_ANALYSIS.REPORT.NO_AGENTS') }}
      </p>
      <div
        v-for="agent in report.agents"
        :key="agent.id"
        class="flex items-center justify-between py-2 border-b border-n-weak last:border-b-0"
      >
        <span class="text-sm text-n-slate-12">{{ agent.name }}</span>
        <span class="flex items-center gap-4">
          <span class="text-xs text-n-slate-11">
            {{
              t('CONVERSATION_ANALYSIS.REPORT.COUNT', { count: agent.count })
            }}
          </span>
          <span
            class="w-10 text-sm font-medium text-right"
            :class="scoreTextClass(agent.average_score)"
          >
            {{ agent.average_score }}
          </span>
        </span>
      </div>
    </section>

    <section class="flex flex-col gap-3">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.REPORT.LOW_SCORES') }}
      </h3>
      <p v-if="!report.low_scores.length" class="text-sm text-n-slate-11">
        {{ t('CONVERSATION_ANALYSIS.REPORT.NO_LOW_SCORES') }}
      </p>
      <button
        v-for="item in report.low_scores"
        :key="item.id"
        type="button"
        class="flex items-start justify-between gap-4 p-3 text-left rounded-lg bg-n-solid-2 hover:bg-n-alpha-2"
        @click="emit('openConversation', item.conversation_id)"
      >
        <span class="flex flex-col min-w-0 gap-1">
          <span class="text-sm text-n-slate-12">
            #{{ item.conversation_id }} · {{ item.contact.name }}
            <template v-if="item.assignee.name">
              · {{ item.assignee.name }}
            </template>
          </span>
          <span
            v-if="item.insight?.summary"
            class="text-xs text-n-slate-11 line-clamp-2"
          >
            {{ item.insight.summary }}
          </span>
        </span>
        <span
          class="text-lg font-semibold shrink-0"
          :class="scoreTextClass(item.quality_score)"
        >
          {{ item.quality_score }}
        </span>
      </button>
    </section>
  </div>
</template>
