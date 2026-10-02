<script setup>
import { computed } from 'vue';
import { useMapGetter, useFunctionGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { CONVERSATION_SIDE_PANELS } from 'dashboard/composables/useConversationSidePanel';

import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactConversations from './ContactConversations.vue';
import ConversationAction from './ConversationAction.vue';
import ConversationParticipant from './ConversationParticipant.vue';
import ContactInfo from './contact/ContactInfo.vue';
import ContactNotes from './contact/ContactNotes.vue';
import ConversationInfo from './ConversationInfo.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import SharedFiles from './SharedFiles.vue';
import CrmInfoPanel from 'dashboard/components/widgets/conversation/CrmInfoPanel.vue';
import Draggable from 'vuedraggable';
import MacrosList from './Macros/List.vue';
import ShopifyOrdersList from 'dashboard/components/widgets/conversation/ShopifyOrdersList.vue';
import LinearIssuesList from 'dashboard/components/widgets/conversation/linear/IssuesList.vue';
import LinearSetupCTA from 'dashboard/components/widgets/conversation/linear/LinearSetupCTA.vue';
import ConversationDeals from 'dashboard/components-next/Deals/ConversationDeals.vue';
import ConversationTickets from 'dashboard/components-next/Tickets/ConversationTickets.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  inboxId: {
    type: Number,
    default: undefined,
  },
  panel: {
    type: String,
    required: true,
    validator: value => value in CONVERSATION_SIDE_PANELS,
  },
});

const {
  updateUISettings,
  isContactSidebarItemOpen,
  conversationSidebarItemsOrder,
  toggleSidebarUIState,
  isOnExpandedLayout,
} = useUISettings();

// Sections are dragged within the panel; the reordered slice is written back
// into the shared order so other panels keep their positions.
const panelSections = computed(() => CONVERSATION_SIDE_PANELS[props.panel]);
const panelItems = computed({
  get: () =>
    conversationSidebarItemsOrder.value.filter(item =>
      panelSections.value.includes(item.name)
    ),
  set: reorderedItems => {
    const queue = [...reorderedItems];
    updateUISettings({
      conversation_sidebar_items_order: conversationSidebarItemsOrder.value.map(
        item => (panelSections.value.includes(item.name) ? queue.shift() : item)
      ),
    });
  },
});

const shopifyIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'shopify'
);

const isShopifyFeatureEnabled = computed(
  () => shopifyIntegration.value.enabled
);

const { isCloudFeatureEnabled } = useAccount();

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const isCrmDealsEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_DEALS)
);
const isCrmTicketsEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_TICKETS)
);

const isLinearFeatureEnabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.LINEAR)
);

const linearIntegration = useFunctionGetter(
  'integrations/getIntegration',
  'linear'
);

const isLinearClientIdConfigured = computed(() => {
  return !!linearIntegration.value?.id;
});

const isLinearConnected = computed(
  () => linearIntegration.value?.enabled || false
);

const currentChat = useMapGetter('getSelectedChat');
const conversationId = computed(() => props.conversationId);
const conversationMetadataGetter = useMapGetter(
  'conversationMetadata/getConversationMetadata'
);
const currentConversationMetaData = computed(() =>
  conversationMetadataGetter.value(conversationId.value)
);
const conversationAdditionalAttributes = computed(
  () => currentConversationMetaData.value.additional_attributes || {}
);

const channelType = computed(() => currentChat.value.meta?.channel);

const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));
const contactAdditionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);

const appliedContactFilter = useMapGetter('getAppliedContactFilter');

const isListScopedToContact = computed(
  () =>
    !isOnExpandedLayout.value &&
    appliedContactFilter.value?.id === contactId.value
);
</script>

<template>
  <div class="w-full">
    <ContactInfo
      v-if="panel === 'contact'"
      :contact="contact"
      :channel-type="channelType"
    />
    <div class="px-2 pt-3 pb-8 list-group">
      <Draggable
        v-model="panelItems"
        animation="200"
        ghost-class="ghost"
        handle=".drag-handle"
        item-key="name"
        class="flex flex-col gap-3"
      >
        <template #item="{ element }">
          <div
            v-if="element.name === 'conversation_actions'"
            class="conversation--actions"
          >
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS')"
              :is-open="isContactSidebarItemOpen('is_conv_actions_open')"
              @toggle="
                value => toggleSidebarUIState('is_conv_actions_open', value)
              "
            >
              <ConversationAction
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
            </AccordionItem>
          </div>
          <div
            v-else-if="element.name === 'conversation_participants'"
            class="conversation--actions"
          >
            <AccordionItem
              :title="$t('CONVERSATION_PARTICIPANTS.SIDEBAR_TITLE')"
              :is-open="isContactSidebarItemOpen('is_conv_participants_open')"
              @toggle="
                value =>
                  toggleSidebarUIState('is_conv_participants_open', value)
              "
            >
              <ConversationParticipant
                :conversation-id="conversationId"
                :inbox-id="inboxId"
              />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'conversation_info'">
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_INFO')"
              :is-open="isContactSidebarItemOpen('is_conv_details_open')"
              compact
              @toggle="
                value => toggleSidebarUIState('is_conv_details_open', value)
              "
            >
              <ConversationInfo
                :conversation-attributes="conversationAdditionalAttributes"
                :contact-attributes="contactAdditionalAttributes"
              />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'contact_attributes'">
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES')"
              :is-open="isContactSidebarItemOpen('is_contact_attributes_open')"
              compact
              @toggle="
                value =>
                  toggleSidebarUIState('is_contact_attributes_open', value)
              "
            >
              <CustomAttributes
                attribute-type="contact_attribute"
                attribute-from="conversation_contact_panel"
                :contact-id="contact.id"
                :empty-state-message="
                  $t('CONVERSATION_CUSTOM_ATTRIBUTES.NO_RECORDS_FOUND')
                "
              />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'crm_info'">
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CRM_INFO')"
              :is-open="isContactSidebarItemOpen('is_crm_info_open')"
              compact
              @toggle="value => toggleSidebarUIState('is_crm_info_open', value)"
            >
              <CrmInfoPanel
                :contact-id="contactId"
                :conversation-id="conversationId"
              />
            </AccordionItem>
          </div>
          <div
            v-else-if="
              element.name === 'previous_conversation' && !isListScopedToContact
            "
          >
            <AccordionItem
              v-if="contact.id"
              :title="
                $t('CONVERSATION_SIDEBAR.ACCORDION.PREVIOUS_CONVERSATION')
              "
              :is-open="isContactSidebarItemOpen('is_previous_conv_open')"
              compact
              @toggle="
                value => toggleSidebarUIState('is_previous_conv_open', value)
              "
            >
              <ContactConversations
                :contact-id="contact.id"
                :conversation-id="conversationId"
              />
            </AccordionItem>
          </div>
          <woot-feature-toggle
            v-else-if="element.name === 'macros'"
            feature-key="macros"
          >
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.MACROS')"
              :is-open="isContactSidebarItemOpen('is_macro_open')"
              compact
              @toggle="value => toggleSidebarUIState('is_macro_open', value)"
            >
              <MacrosList :conversation-id="conversationId" />
            </AccordionItem>
          </woot-feature-toggle>
          <div
            v-else-if="
              element.name === 'linear_issues' &&
              isLinearFeatureEnabled &&
              isLinearClientIdConfigured
            "
          >
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.LINEAR_ISSUES')"
              :is-open="isContactSidebarItemOpen('is_linear_issues_open')"
              compact
              @toggle="
                value => toggleSidebarUIState('is_linear_issues_open', value)
              "
            >
              <LinearSetupCTA v-if="!isLinearConnected" />
              <LinearIssuesList v-else :conversation-id="conversationId" />
            </AccordionItem>
          </div>
          <div
            v-else-if="
              element.name === 'shopify_orders' && isShopifyFeatureEnabled
            "
          >
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHOPIFY_ORDERS')"
              :is-open="isContactSidebarItemOpen('is_shopify_orders_open')"
              compact
              @toggle="
                value => toggleSidebarUIState('is_shopify_orders_open', value)
              "
            >
              <ShopifyOrdersList :contact-id="contactId" />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'deals' && isCrmDealsEnabled">
            <AccordionItem
              :title="$t('DEALS.CONVERSATION.TITLE')"
              :is-open="isContactSidebarItemOpen('is_deals_open')"
              compact
              @toggle="value => toggleSidebarUIState('is_deals_open', value)"
            >
              <ConversationDeals
                :conversation-id="conversationId"
                :contact="contact.id ? contact : null"
              />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'tickets' && isCrmTicketsEnabled">
            <AccordionItem
              :title="$t('TICKETS.CONVERSATION.TITLE')"
              :is-open="isContactSidebarItemOpen('is_tickets_open')"
              compact
              @toggle="value => toggleSidebarUIState('is_tickets_open', value)"
            >
              <ConversationTickets :conversation-id="conversationId" />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'contact_notes'">
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_NOTES')"
              :is-open="isContactSidebarItemOpen('is_contact_notes_open')"
              compact
              @toggle="
                value => toggleSidebarUIState('is_contact_notes_open', value)
              "
            >
              <ContactNotes :contact-id="contactId" />
            </AccordionItem>
          </div>
          <div v-else-if="element.name === 'shared_files'">
            <AccordionItem
              :title="$t('CONVERSATION_SIDEBAR.ACCORDION.SHARED_FILES')"
              :is-open="isContactSidebarItemOpen('is_shared_files_open')"
              compact
              @toggle="
                value => toggleSidebarUIState('is_shared_files_open', value)
              "
            >
              <SharedFiles />
            </AccordionItem>
          </div>
        </template>
      </Draggable>
    </div>
  </div>
</template>

<style lang="scss" scoped>
:deep(.contact--profile) {
  @apply pb-3 border-b border-solid border-n-weak;
}
</style>
