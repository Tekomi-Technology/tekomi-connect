<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactPanel from 'dashboard/routes/dashboard/conversation/ContactPanel.vue';
import CompanyPanel from 'dashboard/components-next/Companies/ConversationPanel/CompanyPanel.vue';
import SidePanelShell from 'dashboard/components-next/Conversation/SidePanelShell.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConversationSidePanel } from 'dashboard/composables/useConversationSidePanel';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import wootConstants from 'dashboard/constants/globals';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const props = defineProps({
  currentChat: {
    required: true,
    type: Object,
  },
});

const { t } = useI18n();
const store = useStore();
const { updateUISettings } = useUISettings();
const { activePanel } = useConversationSidePanel();
const { isCloudFeatureEnabled } = useAccount();
const { width: windowWidth } = useWindowSize();

const isPanelOverlay = computed(
  () => windowWidth.value < wootConstants.SIDE_PANEL_DOCK_BREAKPOINT
);

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const contactGetter = useMapGetter('contacts/getContact');
const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);
const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);

const isAccountFeatureEnabled = flag =>
  isFeatureEnabledonAccount.value(currentAccountId.value, flag);

const isSalesPanelAvailable = computed(
  () =>
    isAccountFeatureEnabled(FEATURE_FLAGS.CRM_DEALS) ||
    isAccountFeatureEnabled(FEATURE_FLAGS.CRM_TICKETS) ||
    Boolean(shopifyIntegration.value?.enabled) ||
    (isCloudFeatureEnabled(FEATURE_FLAGS.LINEAR) &&
      Boolean(linearIntegration.value?.id))
);

const panelTabs = computed(() => [
  { panel: 'contact', label: t('CONVERSATION.SIDEBAR.CONTACT') },
  { panel: 'actions', label: t('CONVERSATION.SIDEBAR.ACTIONS') },
  { panel: 'history', label: t('CONVERSATION.SIDEBAR.HISTORY') },
  ...(isSalesPanelAvailable.value
    ? [{ panel: 'sales', label: t('CONVERSATION.SIDEBAR.SALES') }]
    : []),
]);

const contactId = computed(() => props.currentChat.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));
const companyId = computed(() => contact.value?.company_id);

const showCompanyTab = computed(() =>
  isAccountFeatureEnabled(FEATURE_FLAGS.COMPANIES)
);

const contactTab = ref('contact');

const showContactTabs = computed(
  () => activePanel.value === 'contact' && showCompanyTab.value
);

const isCompanyPanelActive = computed(
  () => showContactTabs.value && contactTab.value === 'company'
);

// Shared by every panel, so it is loaded once here instead of per panel.
watch(
  contactId,
  id => {
    if (id) store.dispatch('contacts/show', { id });
  },
  { immediate: true }
);

onMounted(() => {
  store.dispatch('attributes/get', 0);
  store.dispatch('integrations/get', 'linear');
});

const scrollContainer = ref(null);
const resetScroll = () => {
  scrollContainer.value.scrollTop = 0;
};

const closePanel = () => {
  updateUISettings({ is_contact_sidebar_open: false });
};

const closeOnSmallScreen = () => {
  if (isPanelOverlay.value) closePanel();
};
</script>

<template>
  <SidePanelShell
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
      <button
        v-for="tab in panelTabs"
        :key="tab.panel"
        type="button"
        class="flex-1 pb-2.5 -mb-px text-[13px] whitespace-nowrap border-b-2 transition-colors duration-200"
        :class="
          activePanel === tab.panel
            ? 'font-semibold text-n-teal-11 border-n-teal-9'
            : 'font-medium text-n-slate-11 border-transparent hover:text-n-slate-12'
        "
        @click="activePanel = tab.panel"
      >
        {{ tab.label }}
      </button>
      <Button
        v-tooltip.left="t('CONVERSATION.SIDEBAR.COLLAPSE_PANEL')"
        icon="i-lucide-x"
        slate
        ghost
        xs
        class="self-center flex-shrink-0 mb-0.5"
        @click="closePanel"
      />
    </div>
    <div
      v-if="showContactTabs"
      class="flex flex-shrink-0 gap-1 p-1 mx-3 mt-3 rounded-lg bg-n-alpha-1"
    >
      <button
        v-for="tab in ['contact', 'company']"
        :key="tab"
        type="button"
        class="flex-1 py-1 text-xs rounded-md transition-colors duration-200"
        :class="
          contactTab === tab
            ? 'font-semibold bg-n-solid-1 text-n-slate-12 shadow-sm'
            : 'font-medium text-n-slate-11 hover:text-n-slate-12'
        "
        @click="contactTab = tab"
      >
        {{
          tab === 'contact'
            ? t('CONVERSATION.SIDEBAR.PERSON')
            : t('CONVERSATION.SIDEBAR.COMPANY')
        }}
      </button>
    </div>
    <div ref="scrollContainer" class="flex flex-1 min-h-0 overflow-y-auto">
      <Transition
        mode="out-in"
        enter-active-class="transition duration-200 ease-out motion-reduce:transition-none"
        leave-active-class="transition duration-100 ease-in motion-reduce:transition-none"
        enter-from-class="opacity-0 translate-y-1"
        leave-to-class="opacity-0"
        @before-enter="resetScroll"
      >
        <KeepAlive>
          <CompanyPanel
            v-if="isCompanyPanelActive"
            key="company"
            :company-id="companyId"
            :contact-id="contactId"
          />
          <ContactPanel
            v-else
            :key="activePanel"
            :panel="activePanel"
            :conversation-id="currentChat.id"
            :inbox-id="currentChat.inbox_id"
          />
        </KeepAlive>
      </Transition>
    </div>
  </SidePanelShell>
</template>
