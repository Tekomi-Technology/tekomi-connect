<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useConversationAnalysis } from 'dashboard/composables/useConversationAnalysis';
import ConversationAnalysesAPI from 'dashboard/api/conversationAnalyses';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AnalysisFields from './AnalysisFields.vue';
import {
  CUSTOMER_FIELDS,
  INSIGHT_FIELDS,
  INTEREST_BADGE_CLASSES,
} from './constants';

const props = defineProps({
  contactId: {
    type: Number,
    default: null,
  },
});

const { t } = useI18n();
const { analysisVersion } = useConversationAnalysis();

const analyses = ref([]);
const isLoading = ref(false);

const loadAnalyses = async () => {
  if (!props.contactId) return;
  const contactId = props.contactId;
  isLoading.value = true;
  try {
    const { data } = await ConversationAnalysesAPI.getByContact(contactId);
    if (contactId === props.contactId) analyses.value = data.payload;
  } catch {
    analyses.value = [];
  } finally {
    isLoading.value = false;
  }
};

watch([() => props.contactId, analysisVersion], loadAnalyses, {
  immediate: true,
});

const latestSummary = computed(() => analyses.value[0]?.insight?.summary);

const mergedFields = (section, keys, prefix) =>
  keys
    .map(key => ({
      key,
      label: t(`CONVERSATION_ANALYSIS.${prefix}.FIELDS.${key.toUpperCase()}`),
      value: analyses.value.find(analysis => analysis[section]?.[key])?.[
        section
      ][key],
    }))
    .filter(field => field.value);

const customerFields = computed(() =>
  mergedFields('customer', CUSTOMER_FIELDS, 'CUSTOMER')
);
const insightFields = computed(() =>
  mergedFields('insight', INSIGHT_FIELDS, 'INSIGHT')
);

const interestTrend = computed(() =>
  [...analyses.value].reverse().map(analysis => ({
    id: analysis.id,
    conversationId: analysis.conversation_id,
    level: analysis.insight?.interest_level || 'unknown',
  }))
);
</script>

<template>
  <div class="flex flex-col gap-3 px-2 py-2">
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner class="text-n-brand" />
    </div>
    <p v-else-if="!analyses.length" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION_ANALYSIS.CONTACT_INSIGHTS.EMPTY') }}
    </p>
    <template v-else>
      <span class="text-xs text-n-slate-10">
        {{
          t('CONVERSATION_ANALYSIS.CONTACT_INSIGHTS.BASED_ON', {
            count: analyses.length,
          })
        }}
      </span>
      <p
        v-if="latestSummary"
        class="p-2 text-sm leading-6 rounded-lg bg-n-alpha-2 text-n-slate-12"
      >
        {{ latestSummary }}
      </p>
      <div class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">
          {{ t('CONVERSATION_ANALYSIS.CONTACT_INSIGHTS.INTEREST_TREND') }}
        </span>
        <div class="flex flex-wrap gap-1">
          <span
            v-for="item in interestTrend"
            :key="item.id"
            v-tooltip="`#${item.conversationId}`"
            class="px-2 py-0.5 text-xs rounded-md"
            :class="INTEREST_BADGE_CLASSES[item.level]"
          >
            {{
              t(
                `CONVERSATION_ANALYSIS.INSIGHT.INTEREST_LEVELS.${item.level.toUpperCase()}`
              )
            }}
          </span>
        </div>
      </div>
      <AnalysisFields :items="customerFields" />
      <AnalysisFields :items="insightFields" />
    </template>
  </div>
</template>
