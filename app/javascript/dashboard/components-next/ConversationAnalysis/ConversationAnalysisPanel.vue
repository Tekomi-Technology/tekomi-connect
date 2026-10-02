<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConfig } from 'dashboard/composables/useConfig';
import { useConversationAnalysis } from 'dashboard/composables/useConversationAnalysis';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import wootConstants from 'dashboard/constants/globals';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ConversationAnalysesAPI from 'dashboard/api/conversationAnalyses';
import SidePanelShell from 'dashboard/components-next/Conversation/SidePanelShell.vue';
import SidePanelTransition from 'dashboard/components-next/Conversation/SidePanelTransition.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConversationAnalysisResult from './ConversationAnalysisResult.vue';
import ContactInsights from './ContactInsights.vue';

const props = defineProps({
  conversationId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const { isEnterprise } = useConfig();
const { uiSettings, updateUISettings } = useUISettings();
const { width: windowWidth } = useWindowSize();
const { requestedConversationId, clearRequest, markAnalyzed } =
  useConversationAnalysis();

const currentAccountId = useMapGetter('getCurrentAccountId');
const currentChat = useMapGetter('getSelectedChat');
const contactId = computed(() => currentChat.value.meta?.sender?.id);
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const POLL_INTERVAL = 3000;
const POLL_TIMEOUT = 5 * 60 * 1000;
const EMPTY_JOBS = { analysis: null, care: null };

const analysis = ref(null);
const jobs = ref(EMPTY_JOBS);
const isLoading = ref(false);
const errorMessage = ref('');

let pollTimer = null;
let pollDeadline = null;
let isUnmounted = false;

const isOpen = computed(
  () =>
    isEnterprise &&
    isFeatureEnabledonAccount.value(
      currentAccountId.value,
      FEATURE_FLAGS.TEKOMI
    ) &&
    uiSettings.value.is_conversation_analysis_panel_open
);
const isAnalyzing = computed(
  () => jobs.value.analysis?.status === 'processing'
);
const isGeneratingCare = computed(
  () => jobs.value.care?.status === 'processing'
);
const headerButtons = computed(() =>
  analysis.value && !isAnalyzing.value && !isGeneratingCare.value
    ? [
        {
          key: 'reanalyze',
          icon: 'i-lucide-refresh-cw',
          tooltip: t('CONVERSATION_ANALYSIS.REANALYZE'),
        },
      ]
    : []
);

const isCurrent = conversationId =>
  !isUnmounted && isOpen.value && conversationId === props.conversationId;

const stopPolling = () => {
  clearTimeout(pollTimer);
  pollTimer = null;
  pollDeadline = null;
};

const applyResponse = (conversationId, data) => {
  if (!isCurrent(conversationId)) return;
  const analysisFinished = isAnalyzing.value && !data.jobs.analysis;
  analysis.value = data.payload;
  jobs.value = data.jobs;
  if (analysisFinished) markAnalyzed();

  const { analysis: analysisJob, care: careJob } = data.jobs;
  if (analysisJob?.status === 'failed') {
    errorMessage.value = analysisJob.error || t('CONVERSATION_ANALYSIS.ERROR');
  } else if (careJob?.status === 'failed') {
    errorMessage.value = careJob.error || t('CONVERSATION_ANALYSIS.CARE.ERROR');
  }
};

const schedulePoll = conversationId => {
  if (!isCurrent(conversationId)) return;
  clearTimeout(pollTimer);
  if (!isAnalyzing.value && !isGeneratingCare.value) {
    stopPolling();
    return;
  }
  pollDeadline ||= Date.now() + POLL_TIMEOUT;
  if (Date.now() > pollDeadline) {
    stopPolling();
    jobs.value = EMPTY_JOBS;
    errorMessage.value = t('CONVERSATION_ANALYSIS.TIMEOUT');
    return;
  }
  pollTimer = setTimeout(async () => {
    const response = await ConversationAnalysesAPI.get(conversationId).catch(
      () => null
    );
    if (response) applyResponse(conversationId, response.data);
    schedulePoll(conversationId);
  }, POLL_INTERVAL);
};

const startJob = async (kind, request, errorKey) => {
  const conversationId = props.conversationId;
  errorMessage.value = '';
  jobs.value = { ...jobs.value, [kind]: { status: 'processing' } };
  try {
    const { data } = await request(conversationId);
    applyResponse(conversationId, data);
    schedulePoll(conversationId);
  } catch (error) {
    if (!isCurrent(conversationId)) return;
    jobs.value = { ...jobs.value, [kind]: null };
    errorMessage.value = error.response?.data?.error || t(errorKey);
  }
};

const runAnalysis = () =>
  startJob(
    'analysis',
    id => ConversationAnalysesAPI.create(id),
    'CONVERSATION_ANALYSIS.ERROR'
  );

const generateCare = () =>
  startJob(
    'care',
    id => ConversationAnalysesAPI.createCareSuggestion(id),
    'CONVERSATION_ANALYSIS.CARE.ERROR'
  );

const handleRequest = () => {
  if (
    requestedConversationId.value !== props.conversationId ||
    isLoading.value
  ) {
    return;
  }
  clearRequest();
  if (!analysis.value && !isAnalyzing.value) runAnalysis();
};

const loadAnalysis = async () => {
  const conversationId = props.conversationId;
  stopPolling();
  analysis.value = null;
  jobs.value = EMPTY_JOBS;
  errorMessage.value = '';
  isLoading.value = true;
  try {
    const { data } = await ConversationAnalysesAPI.get(conversationId);
    applyResponse(conversationId, data);
    schedulePoll(conversationId);
  } catch (error) {
    if (conversationId === props.conversationId) {
      errorMessage.value =
        error.response?.data?.error || t('CONVERSATION_ANALYSIS.LOAD_ERROR');
    }
  } finally {
    isLoading.value = false;
  }
  handleRequest();
};

watch(
  [() => props.conversationId, isOpen],
  ([, open]) => {
    if (open) loadAnalysis();
    else stopPolling();
  },
  { immediate: true }
);
watch(requestedConversationId, handleRequest);

onBeforeUnmount(() => {
  isUnmounted = true;
  stopPolling();
});

const closePanel = () => {
  updateUISettings({ is_conversation_analysis_panel_open: false });
};

const closeOnSmallScreen = () => {
  if (windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT) closePanel();
};

const onHeaderClick = key => {
  if (key === 'reanalyze') runAnalysis();
};
</script>

<template>
  <SidePanelTransition>
    <SidePanelShell
      v-if="isOpen"
      v-on-click-outside="[
        closeOnSmallScreen,
        {
          ignore: [
            'dialog.ProseMirror-prompt-backdrop',
            '[data-popover-content]',
            '[data-popover-backdrop]',
          ],
        },
      ]"
      class="flex"
    >
      <div class="flex flex-col w-full h-full">
        <SidebarActionsHeader
          :title="t('CONVERSATION_ANALYSIS.TITLE')"
          :buttons="headerButtons"
          @click="onHeaderClick"
          @close="closePanel"
        />
        <div class="flex-1 overflow-y-auto">
          <div
            v-if="isLoading || isAnalyzing"
            class="flex flex-col items-center gap-3 px-4 py-10 text-center"
          >
            <Spinner class="text-n-brand" />
            <span v-if="isAnalyzing" class="text-sm text-n-slate-11">
              {{ t('CONVERSATION_ANALYSIS.ANALYZING') }}
            </span>
          </div>
          <template v-else>
            <p
              v-if="errorMessage"
              class="px-3 py-2 mx-4 mt-4 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
            >
              {{ errorMessage }}
            </p>
            <template v-if="analysis">
              <ConversationAnalysisResult
                :analysis="analysis"
                :is-generating-care="isGeneratingCare"
                @generate-care="generateCare"
              />
              <p class="px-4 pb-6 text-xs text-n-slate-10">
                {{
                  t('CONVERSATION_ANALYSIS.ANALYZED_BY', {
                    name: analysis.analyzed_by.name,
                    time: dynamicTime(analysis.updated_at),
                  })
                }}
              </p>
            </template>
            <div
              v-else
              class="flex flex-col items-center gap-3 px-4 py-10 text-center"
            >
              <span class="text-sm text-n-slate-11">
                {{ t('CONVERSATION_ANALYSIS.EMPTY') }}
              </span>
              <Button
                :label="t('CONVERSATION_ANALYSIS.ANALYZE')"
                icon="i-lucide-scan-search"
                sm
                @click="runAnalysis"
              />
            </div>
          </template>
          <section
            v-if="contactId"
            class="flex flex-col gap-2.5 px-4 pt-4 pb-6 border-t border-n-weak"
          >
            <h3 class="m-0 text-sm font-semibold text-n-slate-12">
              {{ t('CONVERSATION_SIDEBAR.ACCORDION.CUSTOMER_INSIGHTS') }}
            </h3>
            <ContactInsights :contact-id="contactId" />
          </section>
        </div>
      </div>
    </SidePanelShell>
  </SidePanelTransition>
</template>
