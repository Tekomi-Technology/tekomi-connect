<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AnalysisFields from './AnalysisFields.vue';
import {
  QUALITY_CRITERIA,
  PROFILE_FIELDS,
  INTEREST_BADGE_CLASSES,
  SENTIMENT_BADGE_CLASSES,
  toList,
  hasValue,
  scoreTextClass,
  scoreVerdict,
  criterionBarClass,
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

const SCORE_SEGMENTS = 5;
const openCriteria = ref([]);

const interestLevel = computed(
  () => props.analysis.insight?.interest_level || 'unknown'
);
const sentiment = computed(
  () => props.analysis.insight?.sentiment || 'unknown'
);
const servedBy = computed(() => props.analysis.served_by.toUpperCase());

const openQuestions = computed(() =>
  toList(props.analysis.conversation_state?.open_questions)
);
const alreadyDone = computed(() =>
  toList(props.analysis.conversation_state?.already_done)
);

const profileFields = computed(() =>
  PROFILE_FIELDS.filter(({ section, key }) =>
    hasValue(props.analysis[section]?.[key])
  ).map(({ section, prefix, key }) => ({
    key,
    label: t(`CONVERSATION_ANALYSIS.${prefix}.FIELDS.${key.toUpperCase()}`),
    value: props.analysis[section][key],
  }))
);

const criteria = computed(() =>
  QUALITY_CRITERIA.map(key => ({
    key,
    ...(props.analysis.quality?.[key] || {}),
  }))
);

const isCriterionOpen = key => openCriteria.value.includes(key);
const toggleCriterion = key => {
  openCriteria.value = isCriterionOpen(key)
    ? openCriteria.value.filter(item => item !== key)
    : [...openCriteria.value, key];
};

const care = computed(() => props.analysis.care || {});
const hasCare = computed(() => hasValue(care.value.next_action));
const talkingPoints = computed(() => toList(care.value.talking_points));
const opportunities = computed(() => toList(care.value.opportunity));
</script>

<template>
  <div class="flex flex-col gap-6 px-4 py-4">
    <div class="flex flex-col gap-2.5">
      <p
        v-if="analysis.insight?.summary"
        class="m-0 text-[0.9375rem] leading-6 text-n-slate-12"
      >
        {{ analysis.insight.summary }}
      </p>
      <div class="flex flex-wrap gap-1.5">
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-full"
          :class="INTEREST_BADGE_CLASSES[interestLevel]"
        >
          {{
            t(
              `CONVERSATION_ANALYSIS.INSIGHT.INTEREST_CHIP.${interestLevel.toUpperCase()}`
            )
          }}
        </span>
        <span
          v-if="sentiment !== 'unknown'"
          class="px-2 py-0.5 text-xs font-medium rounded-full"
          :class="SENTIMENT_BADGE_CLASSES[sentiment]"
        >
          {{
            t(
              `CONVERSATION_ANALYSIS.INSIGHT.SENTIMENTS.${sentiment.toUpperCase()}`
            )
          }}
        </span>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-slate-3 text-n-slate-11"
        >
          {{ t(`CONVERSATION_ANALYSIS.QUALITY.SERVED_BY_CHIP.${servedBy}`) }}
        </span>
      </div>
    </div>

    <section class="flex flex-col gap-2.5">
      <h3 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.STATE.TITLE') }}
      </h3>
      <p
        v-if="!openQuestions.length && !alreadyDone.length"
        class="m-0 text-sm text-n-slate-11"
      >
        {{ t('CONVERSATION_ANALYSIS.STATE.EMPTY') }}
      </p>
      <div
        v-if="openQuestions.length"
        class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-amber-3"
      >
        <span class="text-xs font-semibold text-n-amber-11">
          {{ t('CONVERSATION_ANALYSIS.STATE.FIELDS.OPEN_QUESTIONS') }}
        </span>
        <ul
          class="flex flex-col gap-0.5 m-0 text-sm list-disc ltr:pl-4 rtl:pr-4 text-n-slate-12"
        >
          <li v-for="(question, index) in openQuestions" :key="index">
            {{ question }}
          </li>
        </ul>
      </div>
      <div
        v-if="alreadyDone.length"
        class="flex flex-col gap-1.5 p-3 rounded-xl bg-n-alpha-2"
      >
        <span class="text-xs font-semibold text-n-slate-11">
          {{ t('CONVERSATION_ANALYSIS.STATE.FIELDS.ALREADY_DONE') }}
        </span>
        <ul
          class="flex flex-col gap-0.5 m-0 text-sm list-disc ltr:pl-4 rtl:pr-4 text-n-slate-12"
        >
          <li v-for="(item, index) in alreadyDone" :key="index">
            {{ item }}
          </li>
        </ul>
      </div>
    </section>

    <section class="flex flex-col gap-2.5">
      <h3 class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('CONVERSATION_ANALYSIS.CUSTOMER.TITLE') }}
      </h3>
      <p v-if="!profileFields.length" class="m-0 text-sm text-n-slate-11">
        {{ t('CONVERSATION_ANALYSIS.CUSTOMER.EMPTY') }}
      </p>
      <AnalysisFields v-else :items="profileFields" />
    </section>

    <section class="flex flex-col">
      <div class="flex items-baseline justify-between gap-2">
        <h3 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ t('CONVERSATION_ANALYSIS.QUALITY.TITLE') }}
        </h3>
        <span
          v-if="analysis.quality_score !== null"
          class="text-sm font-semibold tabular-nums"
          :class="scoreTextClass(analysis.quality_score)"
        >
          <span class="text-lg">{{ analysis.quality_score }}</span>
          ·
          {{
            t(
              `CONVERSATION_ANALYSIS.QUALITY.VERDICT.${scoreVerdict(analysis.quality_score)}`
            )
          }}
        </span>
      </div>
      <span class="mb-2 text-xs text-n-slate-10">
        {{ t(`CONVERSATION_ANALYSIS.QUALITY.JUDGED.${servedBy}`) }}
      </span>
      <div
        v-for="criterion in criteria"
        :key="criterion.key"
        class="border-t border-n-weak last:border-b"
      >
        <button
          type="button"
          class="grid w-full grid-cols-[1fr_auto_1rem] items-center gap-3 py-2 text-sm text-left bg-transparent border-0 text-n-slate-12"
          :aria-expanded="isCriterionOpen(criterion.key)"
          @click="toggleCriterion(criterion.key)"
        >
          <span>
            {{
              t(
                `CONVERSATION_ANALYSIS.QUALITY.CRITERIA.${criterion.key.toUpperCase()}`
              )
            }}
          </span>
          <span
            v-if="criterion.score"
            v-tooltip="
              t('CONVERSATION_ANALYSIS.QUALITY.CRITERION_SCORE', {
                score: criterion.score,
              })
            "
            class="flex gap-0.5"
          >
            <span
              v-for="segment in SCORE_SEGMENTS"
              :key="segment"
              class="w-3.5 h-1.5 rounded-sm"
              :class="
                segment <= criterion.score
                  ? criterionBarClass(criterion.score)
                  : 'bg-n-slate-5'
              "
            />
          </span>
          <span v-else class="text-xs text-n-slate-10">
            {{ t('CONVERSATION_ANALYSIS.QUALITY.NOT_SCORED') }}
          </span>
          <span
            class="i-lucide-chevron-right size-4 text-n-slate-10 transition-transform"
            :class="{ 'rotate-90': isCriterionOpen(criterion.key) }"
          />
        </button>
        <div
          v-if="isCriterionOpen(criterion.key)"
          class="flex flex-col gap-1.5 pb-2.5 text-sm text-n-slate-11"
        >
          <span v-if="criterion.reason">{{ criterion.reason }}</span>
          <blockquote
            v-for="(quote, index) in toList(criterion.evidence)"
            :key="index"
            class="m-0 italic ltr:pl-2.5 rtl:pr-2.5 ltr:border-l-2 rtl:border-r-2 border-n-weak"
          >
            {{ quote }}
          </blockquote>
        </div>
      </div>
    </section>

    <section class="flex flex-col gap-2.5">
      <div class="flex items-center justify-between">
        <h3 class="m-0 text-sm font-semibold text-n-slate-12">
          {{ t('CONVERSATION_ANALYSIS.CARE.TITLE') }}
        </h3>
        <Button
          v-if="hasCare && !isGeneratingCare"
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
      <div
        v-else-if="hasCare"
        class="flex flex-col gap-3 p-3.5 rounded-xl bg-n-brand/10"
      >
        <div
          class="flex flex-wrap items-center gap-2 text-sm font-semibold text-n-slate-12"
        >
          <span>{{ care.next_action }}</span>
          <span
            v-if="care.contact_timing"
            class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-solid-1 text-n-brand"
          >
            {{ care.contact_timing }}
          </span>
        </div>
        <div v-if="talkingPoints.length" class="flex flex-col gap-0.5">
          <span class="text-xs text-n-slate-11">
            {{ t('CONVERSATION_ANALYSIS.CARE.FIELDS.TALKING_POINTS') }}
          </span>
          <ul
            class="flex flex-col gap-0.5 m-0 text-sm list-disc ltr:pl-4 rtl:pr-4 text-n-slate-12"
          >
            <li v-for="(point, index) in talkingPoints" :key="index">
              {{ point }}
            </li>
          </ul>
        </div>
        <div v-if="opportunities.length" class="flex flex-col gap-0.5">
          <span class="text-xs text-n-slate-11">
            {{ t('CONVERSATION_ANALYSIS.CARE.FIELDS.OPPORTUNITY') }}
          </span>
          <ul
            class="flex flex-col gap-0.5 m-0 text-sm list-disc ltr:pl-4 rtl:pr-4 text-n-slate-12"
          >
            <li v-for="(item, index) in opportunities" :key="index">
              {{ item }}
            </li>
          </ul>
        </div>
      </div>
      <div v-else class="flex flex-col items-start gap-2">
        <span class="text-sm text-n-slate-11">
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
