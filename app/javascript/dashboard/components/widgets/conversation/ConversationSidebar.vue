<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactPanel from 'dashboard/routes/dashboard/conversation/ContactPanel.vue';
import CompanyPanel from 'dashboard/components-next/Companies/ConversationPanel/CompanyPanel.vue';
import SidePanelShell from 'dashboard/components-next/Conversation/SidePanelShell.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConversationSidePanel } from 'dashboard/composables/useConversationSidePanel';
import { useMapGetter, useStore } from 'dashboard/composables/store';
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

const PANEL_TITLES = {
  contact: 'CONVERSATION.SIDEBAR.CONTACT_INFO',
  actions: 'CONVERSATION.SIDEBAR.ACTIONS',
  history: 'CONVERSATION.SIDEBAR.HISTORY',
  sales: 'CONVERSATION.SIDEBAR.SALES',
};

const { t } = useI18n();
const store = useStore();
const { updateUISettings } = useUISettings();
const { activePanel } = useConversationSidePanel();
const { width: windowWidth } = useWindowSize();

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const contactGetter = useMapGetter('contacts/getContact');

const contactId = computed(() => props.currentChat.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));
const companyId = computed(() => contact.value?.company_id);

// Both tabs stay visible for every conversation; contacts without a company
// get an empty state in the company tab instead of a missing tab bar.
const showCompanyTab = computed(() =>
  isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.COMPANIES
  )
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
  updateUISettings({
    is_contact_sidebar_open: false,
    is_copilot_panel_open: false,
  });
};

const closeOnSmallScreen = () => {
  if (isSmallScreen.value) closePanel();
};
</script>

<template>
  <SidePanelShell
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
    <div
      v-if="showContactTabs"
      class="flex items-end flex-shrink-0 h-12 gap-1 px-3 border-b border-n-weak"
    >
      <button
        v-for="tab in ['contact', 'company']"
        :key="tab"
        type="button"
        class="flex-1 pb-2 -mb-px text-sm font-medium border-b-2 transition-colors duration-200"
        :class="
          contactTab === tab
            ? 'text-n-blue-text border-n-brand'
            : 'text-n-slate-11 border-transparent hover:text-n-slate-12'
        "
        @click="contactTab = tab"
      >
        {{
          tab === 'contact'
            ? t('CONVERSATION.SIDEBAR.CONTACT')
            : t('CONVERSATION.SIDEBAR.COMPANY')
        }}
      </button>
      <!-- Same collapse toggle as the conversation list; on phones the panel is an overlay, so it closes. -->
      <Button
        v-tooltip.left="t('CONVERSATION.SIDEBAR.COLLAPSE_PANEL')"
        icon="i-lucide-chevron-right"
        slate
        xs
        faded
        class="self-center flex-shrink-0 hidden mb-1 !rounded-full md:inline-flex rtl:rotate-180"
        @click="closePanel"
      />
      <Button
        v-tooltip="t('GENERAL.CLOSE')"
        icon="i-lucide-x"
        slate
        ghost
        xs
        class="self-center md:hidden"
        @click="closePanel"
      />
    </div>
    <SidebarActionsHeader
      v-else
      class="flex-shrink-0"
      :title="t(PANEL_TITLES[activePanel])"
      @close="closePanel"
    />
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
