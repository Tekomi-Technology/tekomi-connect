<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Copilot from 'dashboard/components-next/copilot/Copilot.vue';
import ConversationAnalysis from 'dashboard/components-next/ConversationAnalysis/ConversationAnalysis.vue';
import SidePanelShell from 'dashboard/components-next/Conversation/SidePanelShell.vue';
import SidePanelTransition from 'dashboard/components-next/Conversation/SidePanelTransition.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConfig } from 'dashboard/composables/useConfig';
import { AI_PANEL_TABS, useAiPanel } from 'dashboard/composables/useAiPanel';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import wootConstants from 'dashboard/constants/globals';
import {
  isAConversationRoute,
  isAInboxViewRoute,
} from 'dashboard/helper/routeHelpers';
import { MESSAGE_TYPE } from 'shared/constants/messages';

defineProps({
  conversationInboxType: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const { uiSettings, updateUISettings } = useUISettings();
const { activeAiTab, isAiAvailable } = useAiPanel();
const { isEnterprise } = useConfig();
const { width: windowWidth } = useWindowSize();

const currentUser = useMapGetter('getCurrentUser');
const assistants = useMapGetter('tekomiAssistants/getRecords');
const uiFlags = useMapGetter('tekomiAssistants/getUIFlags');
const inboxAssistant = useMapGetter('getCopilotAssistant');
const currentChat = useMapGetter('getSelectedChat');
const lastPublicMessage = useMapGetter('getLastEmailInSelectedChat');

const canSuggestReply = computed(
  () => lastPublicMessage.value?.message_type === MESSAGE_TYPE.INCOMING
);

const isPanelOverlay = computed(
  () => windowWidth.value < wootConstants.SIDE_PANEL_DOCK_BREAKPOINT
);

const selectedCopilotThreadId = ref(null);
const messages = computed(() =>
  store.getters['copilotMessages/getMessagesByThreadId'](
    selectedCopilotThreadId.value
  )
);

const selectedAssistantId = ref(null);

const activeAssistant = computed(() => {
  const preferredId = uiSettings.value.preferred_tekomi_assistant_id;

  // If the user has selected a specific assistant, it takes first preference for Copilot.
  if (preferredId) {
    const preferredAssistant = assistants.value.find(a => a.id === preferredId);
    // Return the preferred assistant if found, otherwise continue to next cases
    if (preferredAssistant) return preferredAssistant;
  }

  // If the above is not available, the assistant connected to the inbox takes preference.
  if (inboxAssistant.value) {
    const inboxMatchedAssistant = assistants.value.find(
      a => a.id === inboxAssistant.value.id
    );
    if (inboxMatchedAssistant) return inboxMatchedAssistant;
  }
  // If neither of the above is available, the first assistant in the account takes preference.
  return assistants.value[0];
});

const showAnalysisTab = computed(
  () =>
    Boolean(currentChat.value?.id) &&
    (isAConversationRoute(route?.name) || isAInboxViewRoute(route?.name))
);

const isCopilotTab = computed(
  () => !showAnalysisTab.value || activeAiTab.value === AI_PANEL_TABS.COPILOT
);

const panelTabs = computed(() => [
  { key: AI_PANEL_TABS.COPILOT, label: t('TEKOMI.COPILOT.TAB_COPILOT') },
  { key: AI_PANEL_TABS.ANALYSIS, label: t('TEKOMI.COPILOT.TAB_ANALYSIS') },
]);

const closePanel = () => {
  updateUISettings({ is_copilot_panel_open: false });
};

const closeOnSmallScreen = () => {
  if (isPanelOverlay.value) closePanel();
};

const setAssistant = async assistant => {
  selectedAssistantId.value = assistant.id;
  await updateUISettings({
    preferred_tekomi_assistant_id: assistant.id,
  });
};

const shouldShowCopilotPanel = computed(
  () =>
    isAiAvailable.value &&
    uiSettings.value.is_copilot_panel_open &&
    !uiFlags.value.fetchingList
);

const handleReset = () => {
  selectedCopilotThreadId.value = null;
};

watch(() => currentChat.value?.id, handleReset);

const sendMessage = async payload => {
  const message = typeof payload === 'string' ? payload : payload.message;
  const requestType =
    typeof payload === 'string' ? undefined : payload.requestType;

  try {
    if (selectedCopilotThreadId.value) {
      await store.dispatch('copilotMessages/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: currentChat.value?.id,
        threadId: selectedCopilotThreadId.value,
        message,
      });
    } else {
      const conversationId = currentChat.value?.id;
      const response = await store.dispatch('copilotThreads/create', {
        assistant_id: activeAssistant.value.id,
        conversation_id: conversationId,
        message,
        ...(requestType && { request_type: requestType }),
      });
      if (currentChat.value?.id === conversationId) {
        selectedCopilotThreadId.value = response.id;
      }
    }
  } catch (error) {
    useAlert(error.message);
  }
};

onMounted(() => {
  if (isEnterprise) {
    store.dispatch('tekomiAssistants/get');
  }
});
</script>

<template>
  <SidePanelTransition>
    <SidePanelShell
      v-if="shouldShowCopilotPanel"
      v-on-click-outside="[
        closeOnSmallScreen,
        {
          ignore: [
            '[data-side-panel-toggle]',
            'dialog.ProseMirror-prompt-backdrop',
            '[data-popover-content]',
            '[data-popover-backdrop]',
          ],
        },
      ]"
      class="flex"
    >
      <div
        class="flex items-end flex-shrink-0 h-12 gap-1 px-3 border-b border-n-weak"
      >
        <template v-if="showAnalysisTab">
          <button
            v-for="tab in panelTabs"
            :key="tab.key"
            type="button"
            class="flex-1 pb-2.5 -mb-px text-[13px] whitespace-nowrap border-b-2 transition-colors duration-200"
            :class="
              (tab.key === AI_PANEL_TABS.COPILOT) === isCopilotTab
                ? 'font-semibold text-n-teal-11 border-n-teal-9'
                : 'font-medium text-n-slate-11 border-transparent hover:text-n-slate-12'
            "
            @click="activeAiTab = tab.key"
          >
            {{ tab.label }}
          </button>
        </template>
        <span
          v-else
          class="flex-1 pb-3 text-sm font-semibold truncate text-n-slate-12"
        >
          {{ t('TEKOMI.COPILOT.TITLE') }}
        </span>
        <Button
          v-if="isCopilotTab && messages.length"
          v-tooltip.left="t('TEKOMI.COPILOT.RESET')"
          icon="i-lucide-refresh-ccw"
          slate
          ghost
          xs
          class="self-center flex-shrink-0 mb-0.5"
          @click="handleReset"
        />
        <Button
          v-tooltip.left="t('GENERAL.CLOSE')"
          icon="i-lucide-x"
          slate
          ghost
          xs
          class="self-center flex-shrink-0 mb-0.5"
          @click="closePanel"
        />
      </div>
      <Copilot
        v-if="isCopilotTab"
        :messages="messages"
        :support-agent="currentUser"
        :conversation-inbox-type="conversationInboxType"
        :assistants="assistants"
        :active-assistant="activeAssistant"
        :can-suggest-reply="canSuggestReply"
        class="flex-1 min-h-0"
        @set-assistant="setAssistant"
        @send-message="sendMessage"
      />
      <ConversationAnalysis v-else :conversation-id="currentChat.id" />
    </SidePanelShell>
  </SidePanelTransition>
</template>
