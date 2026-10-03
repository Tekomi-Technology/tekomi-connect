<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationAnalysis } from 'dashboard/composables/useConversationAnalysis';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import ConversationAnalysesAPI from 'dashboard/api/conversationAnalyses';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AnalysisFields from './AnalysisFields.vue';
import { PROFILE_FIELDS, INTEREST_BADGE_CLASSES, hasValue } from './constants';

const props = defineProps({
  contactId: {
    type: Number,
    default: null,
  },
});

const { t } = useI18n();
const { analysisVersion } = useConversationAnalysis();
const accountId = useMapGetter('getCurrentAccountId');

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

const profileFields = computed(() =>
  PROFILE_FIELDS.flatMap(({ section, prefix, key }) => {
    const source = analyses.value.find(analysis =>
      hasValue(analysis[section]?.[key])
    );
    if (!source) return [];
    return {
      key,
      label: t(`CONVERSATION_ANALYSIS.${prefix}.FIELDS.${key.toUpperCase()}`),
      value: source[section][key],
      conversationId: source.conversation_id,
    };
  })
);

const interestTrend = computed(() =>
  [...analyses.value].reverse().map(analysis => ({
    id: analysis.id,
    conversationId: analysis.conversation_id,
    level: analysis.insight?.interest_level || 'unknown',
  }))
);

const conversationPath = id =>
  frontendURL(conversationUrl({ accountId: accountId.value, id }));
</script>

<template>
  <div class="flex flex-col gap-3 px-2 py-2">
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner class="text-n-brand" />
    </div>
    <p v-else-if="!analyses.length" class="m-0 text-sm text-n-slate-11">
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
      <p v-if="latestSummary" class="m-0 text-sm leading-6 text-n-slate-12">
        {{ latestSummary }}
      </p>
      <div class="grid grid-cols-[6.5rem_1fr] gap-x-3">
        <span class="text-sm text-n-slate-10">
          {{ t('CONVERSATION_ANALYSIS.CONTACT_INSIGHTS.INTEREST_TREND') }}
        </span>
        <div class="flex flex-wrap items-center gap-1.5">
          <template v-for="(item, index) in interestTrend" :key="item.id">
            <span
              v-if="index > 0"
              class="i-lucide-arrow-right size-3 text-n-slate-10"
            />
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full"
              :class="INTEREST_BADGE_CLASSES[item.level]"
            >
              {{
                t(
                  `CONVERSATION_ANALYSIS.INSIGHT.INTEREST_LEVELS.${item.level.toUpperCase()}`
                )
              }}
            </span>
            <router-link
              v-tooltip="
                t('CONVERSATION_ANALYSIS.CONTACT_INSIGHTS.OPEN_CONVERSATION', {
                  id: item.conversationId,
                })
              "
              :to="conversationPath(item.conversationId)"
              class="text-xs text-n-brand hover:underline"
            >
              #{{ item.conversationId }}
            </router-link>
          </template>
        </div>
      </div>
      <AnalysisFields :items="profileFields" />
    </template>
  </div>
</template>
