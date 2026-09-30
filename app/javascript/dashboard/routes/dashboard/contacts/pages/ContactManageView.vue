<script setup>
import { onMounted, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute, useRouter } from 'vue-router';

import ContactsDetailsLayout from 'dashboard/components-next/Contacts/ContactsDetailsLayout.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactDetails from 'dashboard/components-next/Contacts/Pages/ContactDetails.vue';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactNotes from 'dashboard/components-next/Contacts/ContactsSidebar/ContactNotes.vue';
import ContactHistory from 'dashboard/components-next/Contacts/ContactsSidebar/ContactHistory.vue';
import ContactMedia from 'dashboard/components-next/Contacts/ContactsSidebar/ContactMedia.vue';
import ContactChannels from 'dashboard/components-next/Contacts/ContactsSidebar/ContactChannels.vue';
import ContactMerge from 'dashboard/components-next/Contacts/ContactsSidebar/ContactMerge.vue';
import ContactCustomAttributes from 'dashboard/components-next/Contacts/ContactsSidebar/ContactCustomAttributes.vue';
import ContactDeals from 'dashboard/components-next/Deals/ContactDeals.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const store = useStore();
const route = useRoute();
const router = useRouter();

const contact = useMapGetter('contacts/getContactById');
const uiFlags = useMapGetter('contacts/getUIFlags');

const openSections = ref(new Set(['attributes', 'channels']));
const contactMergeRef = ref(null);

const isFetchingItem = computed(() => uiFlags.value.isFetchingItem);
const isMergingContact = computed(() => uiFlags.value.isMerging);
const isUpdatingContact = computed(() => uiFlags.value.isUpdating);

const selectedContact = computed(() => contact.value(route.params.contactId));

const showSpinner = computed(
  () => isFetchingItem.value || isMergingContact.value
);

const { t } = useI18n();

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const isDealsEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_DEALS)
);

const isSectionOpen = key => openSections.value.has(key);

const toggleSection = key => {
  if (openSections.value.has(key)) {
    openSections.value.delete(key);
  } else {
    openSections.value.add(key);
  }
};

const goToContactsList = () => {
  if (window.history.state?.back || window.history.length > 1) {
    router.back();
  } else {
    router.push(`/app/accounts/${route.params.accountId}/contacts?page=1`);
  }
};

const fetchActiveContact = async () => {
  if (route.params.contactId) {
    await store.dispatch('contacts/show', { id: route.params.contactId });
    await store.dispatch(
      'contacts/fetchContactableInbox',
      route.params.contactId
    );
  }
};

const fetchContactNotes = () => {
  const { contactId } = route.params;
  if (contactId) store.dispatch('contactNotes/get', { contactId });
};

const fetchContactConversations = () => {
  const { contactId } = route.params;
  if (contactId) store.dispatch('contactConversations/get', contactId);
};

const fetchAttributes = () => {
  store.dispatch('attributes/get');
};

const toggleContactBlock = async isBlocked => {
  const ALERT_MESSAGES = {
    success: {
      block: t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_SUCCESS_MESSAGE'),
      unblock: t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_SUCCESS_MESSAGE'),
    },
    error: {
      block: t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_ERROR_MESSAGE'),
      unblock: t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_ERROR_MESSAGE'),
    },
  };

  try {
    await store.dispatch(`contacts/update`, {
      ...selectedContact.value,
      blocked: !isBlocked,
    });
    useAlert(
      isBlocked ? ALERT_MESSAGES.success.unblock : ALERT_MESSAGES.success.block
    );
  } catch (error) {
    useAlert(
      isBlocked ? ALERT_MESSAGES.error.unblock : ALERT_MESSAGES.error.block
    );
  }
};

onMounted(() => {
  fetchActiveContact();
  fetchContactNotes();
  fetchContactConversations();
  fetchAttributes();
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <ContactsDetailsLayout
      :button-label="$t('CONTACTS_LAYOUT.HEADER.SEND_MESSAGE')"
      :selected-contact="selectedContact"
      is-detail-view
      :show-pagination-footer="false"
      :is-updating="isUpdatingContact"
      @go-to-contacts-list="goToContactsList"
      @toggle-block="toggleContactBlock"
    >
      <div
        v-if="showSpinner"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>
      <ContactDetails
        v-else-if="selectedContact"
        :selected-contact="selectedContact"
        @go-to-contacts-list="goToContactsList"
      />
      <template #sidebar>
        <div
          v-if="isFetchingItem"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div v-else class="flex flex-col gap-2 px-4">
          <AccordionItem
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.ATTRIBUTES')"
            :is-open="isSectionOpen('attributes')"
            @toggle="toggleSection('attributes')"
          >
            <ContactCustomAttributes :selected-contact="selectedContact" />
          </AccordionItem>
          <AccordionItem
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.CHANNELS')"
            :is-open="isSectionOpen('channels')"
            @toggle="toggleSection('channels')"
          >
            <ContactChannels :selected-contact="selectedContact" />
          </AccordionItem>
          <AccordionItem
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.HISTORY')"
            :is-open="isSectionOpen('history')"
            @toggle="toggleSection('history')"
          >
            <ContactHistory />
          </AccordionItem>
          <AccordionItem
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.NOTES')"
            :is-open="isSectionOpen('notes')"
            @toggle="toggleSection('notes')"
          >
            <ContactNotes />
          </AccordionItem>
          <AccordionItem
            v-if="isDealsEnabled"
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.DEALS')"
            :is-open="isSectionOpen('deals')"
            @toggle="toggleSection('deals')"
          >
            <ContactDeals :contact-id="route.params.contactId" />
          </AccordionItem>
          <AccordionItem
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.MEDIA')"
            :is-open="isSectionOpen('media')"
            @toggle="toggleSection('media')"
          >
            <ContactMedia />
          </AccordionItem>
          <AccordionItem
            :title="$t('CONTACTS_LAYOUT.SIDEBAR.TABS.MERGE')"
            :is-open="isSectionOpen('merge')"
            @toggle="toggleSection('merge')"
          >
            <ContactMerge
              ref="contactMergeRef"
              :selected-contact="selectedContact"
              @go-to-contacts-list="goToContactsList"
              @reset-tab="toggleSection('merge')"
            />
          </AccordionItem>
        </div>
      </template>
    </ContactsDetailsLayout>
  </div>
</template>
