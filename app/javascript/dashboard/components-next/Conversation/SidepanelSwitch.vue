<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  DEFAULT_CONVERSATION_SIDE_PANEL,
  useConversationSidePanel,
} from 'dashboard/composables/useConversationSidePanel';
import { computed, watch } from 'vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useMapGetter, useFunctionGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

const { uiSettings, updateUISettings } = useUISettings();
const { activePanel } = useConversationSidePanel();
const { isCloudFeatureEnabled } = useAccount();

const currentAccountId = useMapGetter('getCurrentAccountId');
const currentChat = useMapGetter('getSelectedChat');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const isAccountFeatureEnabled = flag =>
  isFeatureEnabledonAccount.value(currentAccountId.value, flag);

const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);
const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);

const showCopilotTab = computed(() =>
  isAccountFeatureEnabled(FEATURE_FLAGS.TEKOMI)
);

const isSalesPanelAvailable = computed(
  () =>
    isAccountFeatureEnabled(FEATURE_FLAGS.CRM_DEALS) ||
    isAccountFeatureEnabled(FEATURE_FLAGS.CRM_TICKETS) ||
    Boolean(shopifyIntegration.value?.enabled) ||
    (isCloudFeatureEnabled(FEATURE_FLAGS.LINEAR) &&
      Boolean(linearIntegration.value?.id))
);

const sidebarPanels = computed(() => [
  {
    panel: 'contact',
    icon: 'i-ph-user-bold',
    tooltip: 'CONVERSATION.SIDEBAR.CONTACT_INFO',
  },
  {
    panel: 'actions',
    icon: 'i-lucide-clipboard-check',
    tooltip: 'CONVERSATION.SIDEBAR.ACTIONS',
  },
  {
    panel: 'history',
    icon: 'i-lucide-history',
    tooltip: 'CONVERSATION.SIDEBAR.HISTORY',
  },
  ...(isSalesPanelAvailable.value
    ? [
        {
          panel: 'sales',
          icon: 'i-lucide-briefcase-business',
          tooltip: 'CONVERSATION.SIDEBAR.SALES',
        },
      ]
    : []),
]);

const isContactSidebarOpen = computed(
  () => uiSettings.value.is_contact_sidebar_open
);
const isCopilotPanelOpen = computed(
  () => uiSettings.value.is_copilot_panel_open
);
const isAnalysisPanelOpen = computed(
  () => uiSettings.value.is_conversation_analysis_panel_open
);

// Every newly opened conversation starts on the customer info panel.
watch(
  () => currentChat.value.id,
  () => {
    activePanel.value = DEFAULT_CONVERSATION_SIDE_PANEL;
  }
);

const toggleConversationSidebar = () => {
  updateUISettings({
    is_contact_sidebar_open: !isContactSidebarOpen.value,
    is_copilot_panel_open: false,
    is_conversation_analysis_panel_open: false,
  });
};

const openSidebarPanel = panel => {
  activePanel.value = panel;
  updateUISettings({
    is_contact_sidebar_open: true,
    is_copilot_panel_open: false,
    is_conversation_analysis_panel_open: false,
  });
};

const handleCopilotSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: true,
    is_conversation_analysis_panel_open: false,
  });
};

const handleAnalysisSidebarToggle = () => {
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: false,
    is_conversation_analysis_panel_open: true,
  });
};

const keyboardEvents = {
  'Alt+KeyO': {
    action: toggleConversationSidebar,
  },
};
useKeyboardEvents(keyboardEvents);
</script>

<template>
  <ButtonGroup
    class="flex flex-col justify-center items-center absolute top-36 xl:top-24 ltr:right-2 rtl:left-2 bg-n-solid-2/90 backdrop-blur-lg border border-n-weak/50 rounded-full gap-1.5 p-1.5 shadow-sm transition-shadow duration-200 hover:shadow !z-20"
  >
    <Button
      v-for="item in sidebarPanels"
      :key="item.panel"
      v-tooltip.left="$t(item.tooltip)"
      ghost
      slate
      sm
      class="!rounded-full transition-all duration-[250ms] ease-out active:!scale-95 active:!brightness-105 active:duration-75"
      :class="{
        'bg-n-alpha-2 active:shadow-sm':
          isContactSidebarOpen && activePanel === item.panel,
      }"
      :icon="item.icon"
      @click="openSidebarPanel(item.panel)"
    />
    <Button
      v-if="showCopilotTab"
      v-tooltip.left="$t('CONVERSATION.SIDEBAR.COPILOT')"
      ghost
      slate
      sm
      class="!rounded-full transition-all duration-[250ms] ease-out active:!scale-95 active:duration-75"
      :class="{
        'bg-n-alpha-2 !text-n-iris-9 active:!brightness-105 active:shadow-sm':
          isCopilotPanelOpen,
      }"
      icon="i-woot-tekomi"
      @click="handleCopilotSidebarToggle"
    />
    <Button
      v-if="showCopilotTab"
      v-tooltip.left="$t('CONVERSATION.SIDEBAR.ANALYSIS')"
      ghost
      slate
      sm
      class="!rounded-full transition-all duration-[250ms] ease-out active:!scale-95 active:duration-75"
      :class="{
        'bg-n-alpha-2 !text-n-iris-9 active:!brightness-105 active:shadow-sm':
          isAnalysisPanelOpen,
      }"
      icon="i-lucide-scan-search"
      @click="handleAnalysisSidebarToggle"
    />
  </ButtonGroup>
</template>
