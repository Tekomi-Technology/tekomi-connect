<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useCompaniesStore } from 'dashboard/stores/companies';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { formatVND } from 'dashboard/components-next/Deals/constants';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';
import CompanyPanelSection from './CompanyPanelSection.vue';

const props = defineProps({
  companyId: { type: [Number, String], default: null },
  contactId: { type: Number, default: null },
});

const PREVIEW_LIMIT = 5;
const NOTES_LIMIT = 3;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const companiesStore = useCompaniesStore();

const accountId = useMapGetter('getCurrentAccountId');
const currentChat = useMapGetter('getSelectedChat');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const companyAttributes = useMapGetter('attributes/getCompanyAttributes');

const isCrmDealsEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_DEALS)
);

const company = computed(() =>
  companiesStore.getRecord(Number(props.companyId))
);
const hasCompany = computed(() => Boolean(company.value?.id));
const isLoadingCompany = computed(
  () => companiesStore.getUIFlags.fetchingItem && !hasCompany.value
);

const additionalAttributes = computed(
  () => company.value?.additionalAttributes || {}
);
const crmId = computed(
  () => additionalAttributes.value.external?.perfexCustomerId
);

const websiteUrl = computed(() => {
  const domain = company.value?.domain;
  if (!domain) return '';
  return /^https?:\/\//.test(domain) ? domain : `https://${domain}`;
});

const hasValue = value => value !== '' && value !== null && value !== undefined;

// Rows without a value are hidden rather than shown as placeholders.
const infoRows = computed(() => {
  const values = company.value?.customAttributes || {};
  const definitions = companyAttributes.value || [];
  const labelFor = key =>
    definitions.find(attribute => attribute.attributeKey === key)
      ?.attributeDisplayName || key;

  return [
    {
      key: 'crm_id',
      label: t('COMPANIES.CONVERSATION_PANEL.INFO.CRM_ID'),
      value: crmId.value,
    },
    {
      key: 'phone',
      label: t('COMPANIES.CONVERSATION_PANEL.PHONE'),
      value: additionalAttributes.value.phonenumber,
    },
    ...Object.entries(values).map(([key, value]) => ({
      key,
      label: labelFor(key),
      value: Array.isArray(value) ? value.join(', ') : value,
    })),
  ].filter(row => hasValue(row.value));
});

const contacts = computed(() => companiesStore.companyContacts);
const contactsCount = computed(() =>
  Number(
    companiesStore.companyContactsMeta.totalCount ??
      company.value?.contactsCount ??
      0
  )
);
const mainContact = computed(
  () =>
    contacts.value.find(contact => contact.id === props.contactId) ||
    contacts.value[0]
);
const otherContacts = computed(() =>
  contacts.value
    .filter(contact => contact.id !== mainContact.value?.id)
    .slice(0, PREVIEW_LIMIT - 1)
);
const openConversations = computed(() =>
  companiesStore.companyConversations.filter(
    conversation => conversation.status === 'open'
  )
);
const openDeals = computed(() =>
  companiesStore.companyDeals.filter(deal => !deal.closedAt)
);
const openDealsValue = computed(() =>
  openDeals.value.reduce((sum, deal) => sum + Number(deal.value || 0), 0)
);
const notes = computed(() => companiesStore.companyNotes.slice(0, NOTES_LIMIT));

const subtitle = computed(() =>
  t('COMPANIES.CONTACTS_COUNT', { n: contactsCount.value })
);

// Sections with data open by default, as in the contact tab; a click
// overrides that until another company is shown.
const sectionHasData = computed(() => ({
  info:
    Boolean(company.value?.description) ||
    Boolean(websiteUrl.value) ||
    infoRows.value.length > 0,
  contacts: contacts.value.length > 0,
  conversations: openConversations.value.length > 0,
  deals: openDeals.value.length > 0,
  notes: notes.value.length > 0,
}));
const openOverrides = ref({});
const isSectionOpen = name =>
  openOverrides.value[name] ?? sectionHasData.value[name];
const toggleSection = name => {
  openOverrides.value = {
    ...openOverrides.value,
    [name]: !isSectionOpen(name),
  };
};

const openCompany = () => {
  router.push({
    name: 'companies_dashboard_show',
    params: { accountId: route.params.accountId, companyId: props.companyId },
  });
};

const openContact = contactId => {
  router.push({
    name: 'contacts_edit',
    params: { accountId: route.params.accountId, contactId },
  });
};

const conversationPath = id =>
  frontendURL(conversationUrl({ accountId: accountId.value, id }));

watch(
  () => Number(props.companyId),
  id => {
    companiesStore.resetCompanyDetailState();
    openOverrides.value = {};
    if (!id) return;
    companiesStore.show(id);
    companiesStore.getCompanyContacts(id);
    companiesStore.getCompanyConversations(id);
    companiesStore.getCompanyNotes(id);
    if (isCrmDealsEnabled.value) companiesStore.getCompanyDeals(id);
  },
  { immediate: true }
);
</script>

<template>
  <div class="w-full">
    <div
      v-if="isLoadingCompany"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>

    <div v-else-if="hasCompany" class="flex flex-col gap-4 p-4">
      <div class="flex items-start justify-between gap-2">
        <div class="flex items-center min-w-0 gap-3">
          <Avatar
            :name="company.name || ''"
            :src="company.avatarUrl"
            :size="44"
            rounded-full
            hide-offline-status
          />
          <div class="flex flex-col min-w-0">
            <h3
              class="m-0 text-sm font-semibold break-words text-n-slate-12"
              :title="company.name"
            >
              {{ company.name }}
            </h3>
            <span class="text-xs text-n-slate-11">{{ subtitle }}</span>
          </div>
        </div>
        <Button
          v-tooltip.top-end="t('COMPANIES.CONVERSATION_PANEL.OPEN_COMPANY')"
          :label="t('COMPANIES.CONVERSATION_PANEL.DETAILS')"
          icon="i-lucide-external-link"
          slate
          outline
          xs
          class="flex-shrink-0"
          @click="openCompany"
        />
      </div>

      <CompanyPanelSection
        :title="t('COMPANIES.CONVERSATION_PANEL.PROFILE.TITLE')"
        :is-open="isSectionOpen('info')"
        @toggle="toggleSection('info')"
      >
        <div
          class="flex flex-col gap-2 p-3 text-xs border rounded-lg bg-n-slate-2 border-n-weak"
        >
          <p v-if="company.description" class="mb-0 text-n-slate-12">
            {{ company.description }}
          </p>
          <div
            v-for="row in infoRows"
            :key="row.key"
            class="flex items-start justify-between gap-3"
          >
            <span class="flex-shrink-0 text-n-slate-11">{{ row.label }}</span>
            <span
              class="min-w-0 font-medium text-right break-words text-n-slate-12"
            >
              {{ row.value }}
            </span>
          </div>
          <div v-if="websiteUrl" class="flex items-start justify-between gap-3">
            <span class="flex-shrink-0 text-n-slate-11">
              {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.WEBSITE') }}
            </span>
            <a
              :href="websiteUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center min-w-0 gap-1 font-medium break-all text-n-blue-text hover:underline"
            >
              {{ company.domain }}
              <span class="flex-shrink-0 i-lucide-external-link size-3" />
            </a>
          </div>
          <p v-if="!sectionHasData.info" class="mb-0 text-n-slate-11">
            {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.EMPTY') }}
          </p>
        </div>
      </CompanyPanelSection>

      <CompanyPanelSection
        :title="t('COMPANIES.CONVERSATION_PANEL.SECTIONS.MAIN_CONTACT')"
        :is-open="isSectionOpen('contacts')"
        @toggle="toggleSection('contacts')"
      >
        <template v-if="contactsCount > 1" #action>
          <button
            type="button"
            class="flex-shrink-0 text-[11px] font-medium text-n-blue-text hover:underline"
            @click="openCompany"
          >
            {{
              t('COMPANIES.CONVERSATION_PANEL.VIEW_ALL_COUNT', {
                n: contactsCount,
              })
            }}
          </button>
        </template>
        <div
          v-if="mainContact"
          class="flex flex-col gap-2.5 p-3 border rounded-lg bg-n-solid-1 border-n-weak"
        >
          <div class="flex items-center justify-between gap-2">
            <button
              type="button"
              class="flex items-center min-w-0 gap-2 text-left"
              @click="openContact(mainContact.id)"
            >
              <Avatar
                :name="mainContact.name || ''"
                :src="mainContact.thumbnail"
                :size="32"
                rounded-full
                hide-offline-status
              />
              <span class="flex flex-col min-w-0">
                <span class="text-xs font-semibold truncate text-n-slate-12">
                  {{ mainContact.name }}
                </span>
                <span
                  v-if="mainContact.id === contactId"
                  class="text-[11px] text-n-teal-11"
                >
                  {{ t('COMPANIES.CONVERSATION_PANEL.CURRENT_CONTACT') }}
                </span>
              </span>
            </button>
            <div class="flex items-center flex-shrink-0 gap-1">
              <VoiceCallButton
                v-if="mainContact.phoneNumber"
                :phone="mainContact.phoneNumber"
                :contact-id="mainContact.id"
                :conversation-id="currentChat?.id"
                icon="i-ph-phone"
                size="xs"
                ghost
                slate
                :tooltip-label="t('CONTACT_PANEL.CALL')"
              />
              <a
                v-if="mainContact.email"
                v-tooltip.top-end="mainContact.email"
                :href="`mailto:${mainContact.email}`"
                class="flex items-center justify-center rounded-lg size-6 text-n-slate-11 hover:bg-n-alpha-2"
              >
                <span class="i-ph-envelope-simple size-4" />
              </a>
            </div>
          </div>
          <div
            v-if="mainContact.email || mainContact.phoneNumber"
            class="flex flex-col gap-1 pt-2 text-xs border-t border-n-weak text-n-slate-11"
          >
            <span v-if="mainContact.email" class="flex items-center gap-2">
              <span
                class="flex-shrink-0 i-ph-envelope-simple text-n-slate-10"
              />
              <span class="truncate">{{ mainContact.email }}</span>
            </span>
            <span
              v-if="mainContact.phoneNumber"
              class="flex items-center gap-2"
            >
              <span class="flex-shrink-0 i-ph-phone text-n-slate-10" />
              <span>{{ mainContact.phoneNumber }}</span>
            </span>
          </div>
        </div>
        <ul
          v-if="otherContacts.length"
          class="flex flex-col gap-0.5 m-0 mt-2 list-none"
        >
          <li v-for="item in otherContacts" :key="item.id">
            <button
              type="button"
              class="flex items-center w-full gap-2 px-2 py-1.5 text-left rounded-md hover:bg-n-alpha-1"
              @click="openContact(item.id)"
            >
              <Avatar
                :name="item.name || ''"
                :src="item.thumbnail"
                :size="24"
                rounded-full
                hide-offline-status
              />
              <span class="flex-1 min-w-0 text-xs truncate text-n-slate-12">
                {{ item.name }}
              </span>
              <span
                v-if="item.email || item.phoneNumber"
                class="text-[11px] truncate text-n-slate-10 max-w-[45%]"
              >
                {{ item.email || item.phoneNumber }}
              </span>
            </button>
          </li>
        </ul>
        <p v-if="!contacts.length" class="mb-0 text-xs text-n-slate-11">
          {{ t('COMPANIES.CONVERSATION_PANEL.SECTIONS.EMPTY') }}
        </p>
      </CompanyPanelSection>

      <CompanyPanelSection
        :title="
          t('COMPANIES.CONVERSATION_PANEL.SECTIONS.CONVERSATIONS', {
            n: openConversations.length,
          })
        "
        :is-open="isSectionOpen('conversations')"
        @toggle="toggleSection('conversations')"
      >
        <ul
          v-if="openConversations.length"
          class="flex flex-col m-0 overflow-hidden list-none border divide-y rounded-lg border-n-weak divide-n-weak"
        >
          <li
            v-for="conversation in openConversations.slice(0, PREVIEW_LIMIT)"
            :key="conversation.id"
          >
            <router-link
              :to="conversationPath(conversation.id)"
              class="flex flex-col gap-0.5 px-3 py-2 hover:bg-n-alpha-1"
            >
              <span class="flex items-center justify-between gap-2">
                <span class="text-xs font-medium truncate text-n-slate-12">
                  {{ conversation.meta?.sender?.name }}
                </span>
                <span class="flex-shrink-0 text-[11px] text-n-slate-10">
                  {{ dynamicTime(conversation.lastActivityAt) }}
                </span>
              </span>
              <span
                v-if="conversation.lastNonActivityMessage?.content"
                class="text-xs truncate text-n-slate-11"
              >
                {{ conversation.lastNonActivityMessage.content }}
              </span>
            </router-link>
          </li>
        </ul>
        <p v-else class="mb-0 text-xs text-n-slate-11">
          {{ t('COMPANIES.CONVERSATION_PANEL.SECTIONS.EMPTY') }}
        </p>
      </CompanyPanelSection>

      <CompanyPanelSection
        v-if="isCrmDealsEnabled"
        :title="
          t('COMPANIES.CONVERSATION_PANEL.SECTIONS.DEALS', {
            n: openDeals.length,
          })
        "
        :is-open="isSectionOpen('deals')"
        @toggle="toggleSection('deals')"
      >
        <template v-if="openDeals.length" #action>
          <span
            class="flex-shrink-0 text-[11px] font-medium text-n-slate-11 tabular-nums"
          >
            {{ formatVND(openDealsValue) }}
          </span>
        </template>
        <ul
          v-if="openDeals.length"
          class="flex flex-col m-0 overflow-hidden list-none border divide-y rounded-lg border-n-weak divide-n-weak"
        >
          <li
            v-for="deal in openDeals.slice(0, PREVIEW_LIMIT)"
            :key="deal.id"
            class="flex items-center justify-between gap-2 px-3 py-2"
          >
            <span class="text-xs font-medium truncate text-n-slate-12">
              {{ deal.name }}
            </span>
            <span
              v-if="deal.value"
              class="flex-shrink-0 text-[11px] font-medium text-n-slate-11 tabular-nums"
            >
              {{ formatVND(deal.value) }}
            </span>
          </li>
        </ul>
        <p v-else class="mb-0 text-xs text-n-slate-11">
          {{ t('COMPANIES.CONVERSATION_PANEL.SECTIONS.EMPTY') }}
        </p>
      </CompanyPanelSection>

      <CompanyPanelSection
        v-if="notes.length"
        :title="t('COMPANIES.CONVERSATION_PANEL.SECTIONS.NOTES')"
        :is-open="isSectionOpen('notes')"
        @toggle="toggleSection('notes')"
      >
        <ul
          class="flex flex-col gap-1.5 p-3 pl-7 m-0 text-xs list-disc border rounded-lg bg-n-slate-2 border-n-weak text-n-slate-12"
        >
          <li v-for="note in notes" :key="note.id" class="break-words">
            {{ note.content }}
          </li>
        </ul>
      </CompanyPanelSection>
    </div>

    <p v-else class="px-4 py-8 text-sm text-center text-n-slate-11">
      {{
        companyId
          ? t('COMPANIES.CONVERSATION_PANEL.EMPTY')
          : t('CONVERSATION.SIDEBAR.NO_COMPANY')
      }}
    </p>
  </div>
</template>
