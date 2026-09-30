<script setup>
import { computed, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactPanel from 'dashboard/routes/dashboard/conversation/ContactPanel.vue';
import CompanyPanel from 'dashboard/components-next/Companies/ConversationPanel/CompanyPanel.vue';
import SidePanelShell from 'dashboard/components-next/Conversation/SidePanelShell.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
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

const { uiSettings, updateUISettings } = useUISettings();
const { width: windowWidth } = useWindowSize();

const activeTab = computed(() => {
  const { is_contact_sidebar_open: isContactSidebarOpen } = uiSettings.value;

  if (isContactSidebarOpen) {
    return 0;
  }
  return null;
});

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

const showCompanyTab = computed(
  () =>
    Boolean(companyId.value) &&
    isFeatureEnabledonAccount.value(
      currentAccountId.value,
      FEATURE_FLAGS.COMPANIES
    )
);

const activePanel = ref('contact');

const isCompanyPanelActive = computed(
  () => showCompanyTab.value && activePanel.value === 'company'
);

watch(showCompanyTab, canShowCompany => {
  if (!canShowCompany) activePanel.value = 'contact';
});

const closeContactPanel = () => {
  if (isSmallScreen.value && uiSettings.value?.is_contact_sidebar_open) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
    });
  }
};
</script>

<template>
  <SidePanelShell
    v-on-click-outside="[
      () => closeContactPanel(),
      {
        ignore: [
          'dialog.ProseMirror-prompt-backdrop',
          '[data-popover-content]',
          '[data-popover-backdrop]',
        ],
      },
    ]"
    class="flex"
    :class="[
      {
        'md:flex': activeTab === 0,
        'md:hidden': activeTab !== 0,
      },
    ]"
  >
    <div v-show="activeTab === 0" class="flex flex-col flex-1 min-h-0">
      <div
        v-if="showCompanyTab || isSmallScreen"
        class="flex flex-shrink-0 items-center gap-1 px-3 pt-2"
        :class="{ 'border-b border-n-weak': showCompanyTab }"
      >
        <button
          v-for="panel in showCompanyTab ? ['contact', 'company'] : []"
          :key="panel"
          type="button"
          class="flex-1 pb-2 -mb-px text-sm font-medium border-b-2"
          :class="
            activePanel === panel
              ? 'text-n-blue-text border-n-brand'
              : 'text-n-slate-11 border-transparent hover:text-n-slate-12'
          "
          @click="activePanel = panel"
        >
          {{
            panel === 'contact'
              ? $t('CONVERSATION.SIDEBAR.CONTACT')
              : $t('CONVERSATION.SIDEBAR.COMPANY')
          }}
        </button>
        <Button
          v-tooltip="$t('GENERAL.CLOSE')"
          icon="i-lucide-x"
          slate
          ghost
          xs
          class="mb-1 md:hidden ms-auto"
          @click="closeContactPanel"
        />
      </div>
      <div class="flex flex-1 min-h-0 overflow-auto">
        <CompanyPanel
          v-if="isCompanyPanelActive"
          :company-id="companyId"
          :contact="contact"
        />
        <ContactPanel
          v-show="!isCompanyPanelActive"
          :conversation-id="currentChat.id"
          :inbox-id="currentChat.inbox_id"
        />
      </div>
    </div>
  </SidePanelShell>
</template>
