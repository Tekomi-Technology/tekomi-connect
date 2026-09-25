<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AnalysisFields from './AnalysisFields.vue';
import {
  QUALITY_CRITERIA,
  CUSTOMER_FIELDS,
  INSIGHT_FIELDS,
  STATE_FIELDS,
  CARE_FIELDS,
  INTEREST_BADGE_CLASSES,
  SENTIMENT_BADGE_CLASSES,
  scoreTextClass,
} from './constants';

const props = defineProps({
  analysis: {
    type: Object,
    required: true,
  },
  isGeneratingCare: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['generateCare']);

const { t } = useI18n();

const criteria = computed(() =>
  QUALITY_CRITERIA.map(key => ({
    key,
    ...(props.analysis.quality?.[key] || {}),
  }))
);

const buildFields = (source, keys, prefix) =>
  keys
    .map(key => ({
      key,
      label: t(`CONVERSATION_ANALYSIS.${prefix}.FIELDS.${key.toUpperCase()}`),
      value: source?.[key],
    }))
    .filter(field => field.value);

const customerFields = computed(() =>
  buildFields(props.analysis.customer, CUSTOMER_FIELDS, 'CUSTOMER')
);
const insightFields = computed(() =>
  buildFields(props.analysis.insight, INSIGHT_FIELDS, 'INSIGHT')
);
const stateFields = computed(() =>
  buildFields(props.analysis.conversation_state, STATE_FIELDS, 'STATE')
);
const careFields = computed(() =>
  buildFields(props.analysis.care, CARE_FIELDS, 'CARE')
);

const interestLevel = computed(
  () => props.analysis.insight?.interest_level || 'unknown'
);
const sentiment = computed(
  () => props.analysis.insight?.sentiment || 'unknown'
);
</script>

<template>
  <div class="flex flex-col gap-5 px-4 py-4">
    <p
      v-if="analysis.insight?.summary"
      class="p-3 text-sm leading-6 rounded-lg bg-n-alpha-2 text-n-slate-12"
    >
      {{ analysis.insight.summary }}
    </p>

    <section class="flex flex-col gap-3">
      <div class="flex items-center justify-between">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION_ANALYSIS.QUALITY.TITLE') }}
        </h3>
        <span
          class="text-xl font-semibold"
          :class="scoreTextClass(analysis.quality_score)"
        >
          {{
            analysis.quality_score === null
              ? '—'
              : t('CONVERSATION_ANALYSIS.QUALITY.SCORE', {
                  score: analysis.quality_score,
                })
          }}
        </span>
      </div>
      <span class="text-xs text-n-slate-11">
        {{
          t('CONVERSATION_ANALYSIS.QUALITY.SERVED_BY', {
            servedBy: t(
              `CONVERSATION_ANALYSIS.QUALITY.SERVED_BY_OPTIONS.${analysis.served_by.toUpperCase()}`
            ),
          })
        }}
      </span>
      <div
        v-for="criterion in criteria"
        :key="criterion.key"
        class="flex flex-col gap-1 pb-3 border-b border-n-weak last:border-b-0 last:pb-0"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm text-n-slate-12">
            {{
              t(
                `CONVERSATION_ANALYSIS.QUALITY.CRITERIA.${criterion.key.toUpperCase()}`
              )
            }}
          </span>
          <span
            class="text-sm font-medium"
            :class="
              criterion.score ? scoreTextClass(criterion.score * 20) : ''
            "
          >
            {{
              criterion.score
                ? t('CONVERSATION_ANALYSIS.QUALITY.CRITERION_SCORE', {
                    score: criterion.score,
                  })
                : t('CONVERSATION_ANALYSIS.QUALITY.NOT_SCORED')
            }}
          </span>
        </div>
        <p v-if="criterion.reason" class="text-xs leading-5 text-n-slate-11">
          {{ criterion.reason }}
        </p>
        <blockquote
          v-for="(quote, index) in criterion.evidence || []"
          :key="index"
          class="px-2 text-xs italic leading-5 ltr:border-l-2 rtl:border-r-2 border-n-weak text-n-slate-11"
        >
          {{ quote }}
        </blockquote>
      </div>
    </section>

    <section class="flex flex-col gap-2">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.CUSTOMER.TITLE') }}
      </h3>
      <p v-if="!customerFields.length" class="text-xs text-n-slate-11">
        {{ t('CONVERSATION_ANALYSIS.CUSTOMER.EMPTY') }}
      </p>
      <AnalysisFields :items="customerFields" />
    </section>

    <section class="flex flex-col gap-2">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.INSIGHT.TITLE') }}
      </h3>
      <div class="flex flex-wrap gap-1">
        <span
          class="px-2 py-0.5 text-xs rounded-md"
          :class="INTEREST_BADGE_CLASSES[interestLevel]"
        >
          {{
            t('CONVERSATION_ANALYSIS.INSIGHT.INTEREST', {
              level: t(
                `CONVERSATION_ANALYSIS.INSIGHT.INTEREST_LEVELS.${interestLevel.toUpperCase()}`
              ),
            })
          }}
        </span>
        <span
          class="px-2 py-0.5 text-xs rounded-md"
          :class="SENTIMENT_BADGE_CLASSES[sentiment]"
        >
          {{
            t('CONVERSATION_ANALYSIS.INSIGHT.SENTIMENT', {
              sentiment: t(
                `CONVERSATION_ANALYSIS.INSIGHT.SENTIMENTS.${sentiment.toUpperCase()}`
              ),
            })
          }}
        </span>
      </div>
      <AnalysisFields :items="insightFields" />
    </section>

    <section class="flex flex-col gap-2">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.STATE.TITLE') }}
      </h3>
      <p v-if="!stateFields.length" class="text-xs text-n-slate-11">
        {{ t('CONVERSATION_ANALYSIS.STATE.EMPTY') }}
      </p>
      <AnalysisFields :items="stateFields" />
    </section>

    <section class="flex flex-col gap-2">
      <div class="flex items-center justify-between">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ t('CONVERSATION_ANALYSIS.CARE.TITLE') }}
        </h3>
        <Button
          v-if="careFields.length && !isGeneratingCare"
          :label="t('CONVERSATION_ANALYSIS.CARE.REGENERATE')"
          icon="i-lucide-refresh-cw"
          ghost
          xs
          @click="emit('generateCare')"
        />
      </div>
      <div
        v-if="isGeneratingCare"
        class="flex items-center gap-2 text-sm text-n-slate-11"
      >
        <Spinner class="text-n-brand" />
        {{ t('CONVERSATION_ANALYSIS.CARE.GENERATING') }}
      </div>
      <AnalysisFields v-else-if="careFields.length" :items="careFields" />
      <div v-else class="flex flex-col items-start gap-2">
        <span class="text-xs text-n-slate-11">
          {{ t('CONVERSATION_ANALYSIS.CARE.HINT') }}
        </span>
        <Button
          :label="t('CONVERSATION_ANALYSIS.CARE.GENERATE')"
          icon="i-lucide-lightbulb"
          sm
          @click="emit('generateCare')"
        />
      </div>
    </section>
  </div>
</template>
