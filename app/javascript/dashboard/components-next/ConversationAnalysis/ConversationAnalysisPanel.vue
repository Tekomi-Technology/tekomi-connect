<script setup>
import { ref, computed, watch } from 'vue';
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
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConversationAnalysisResult from './ConversationAnalysisResult.vue';

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
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const analysis = ref(null);
const isLoading = ref(false);
const analyzingConversationId = ref(null);
const generatingCareConversationId = ref(null);
const errorMessage = ref('');

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
  () => analyzingConversationId.value === props.conversationId
);
const isGeneratingCare = computed(
  () => generatingCareConversationId.value === props.conversationId
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

const runAnalysis = async () => {
  const conversationId = props.conversationId;
  analyzingConversationId.value = conversationId;
  errorMessage.value = '';
  try {
    const { data } = await ConversationAnalysesAPI.create(conversationId);
    if (conversationId === props.conversationId) {
      analysis.value = data.payload;
    }
    markAnalyzed();
  } catch (error) {
    if (conversationId === props.conversationId) {
      errorMessage.value =
        error.response?.data?.error || t('CONVERSATION_ANALYSIS.ERROR');
    }
  } finally {
    if (analyzingConversationId.value === conversationId) {
      analyzingConversationId.value = null;
    }
  }
};

const generateCare = async () => {
  const conversationId = props.conversationId;
  generatingCareConversationId.value = conversationId;
  errorMessage.value = '';
  try {
    const { data } =
      await ConversationAnalysesAPI.createCareSuggestion(conversationId);
    if (conversationId === props.conversationId) {
      analysis.value = data.payload;
    }
  } catch (error) {
    if (conversationId === props.conversationId) {
      errorMessage.value =
        error.response?.data?.error || t('CONVERSATION_ANALYSIS.CARE.ERROR');
    }
  } finally {
    if (generatingCareConversationId.value === conversationId) {
      generatingCareConversationId.value = null;
    }
  }
};

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
  analysis.value = null;
  errorMessage.value = '';
  isLoading.value = true;
  try {
    const { data } = await ConversationAnalysesAPI.get(conversationId);
    if (conversationId === props.conversationId) {
      analysis.value = data.payload;
    }
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
  },
  { immediate: true }
);
watch(requestedConversationId, handleRequest);

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
      </div>
    </div>
  </SidePanelShell>
</template>
