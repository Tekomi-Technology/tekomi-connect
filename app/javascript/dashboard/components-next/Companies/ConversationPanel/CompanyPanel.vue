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

import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactInfoRow from 'dashboard/routes/dashboard/conversation/contact/ContactInfoRow.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  companyId: { type: [Number, String], default: null },
  contactId: { type: Number, default: null },
});

const PREVIEW_LIMIT = 5;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const companiesStore = useCompaniesStore();

const accountId = useMapGetter('getCurrentAccountId');
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
const phone = computed(() => additionalAttributes.value.phonenumber || '');

const websiteUrl = computed(() => {
  const domain = company.value?.domain;
  if (!domain) return '';
  return /^https?:\/\//.test(domain) ? domain : `https://${domain}`;
});

const attributeRows = computed(() => {
  const values = company.value?.customAttributes || {};
  const definitions = companyAttributes.value || [];
  const labelFor = key =>
    definitions.find(attribute => attribute.attributeKey === key)
      ?.attributeDisplayName || key;

  return Object.entries(values)
    .filter(
      ([, value]) => value !== '' && value !== null && value !== undefined
    )
    .map(([key, value]) => ({
      key,
      label: labelFor(key),
      value: Array.isArray(value) ? value.join(', ') : String(value),
    }));
});

const contacts = computed(() => companiesStore.companyContacts);
const contactsCount = computed(() =>
  Number(
    companiesStore.companyContactsMeta.totalCount ??
      company.value?.contactsCount ??
      0
  )
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

const subtitle = computed(() =>
  [
    crmId.value
      ? t('COMPANIES.CONVERSATION_PANEL.CRM_ID', { id: crmId.value })
      : null,
    t('COMPANIES.CONTACTS_COUNT', { n: contactsCount.value }),
  ]
    .filter(Boolean)
    .join(' · ')
);

// Sections with data open by default, as in the contact tab; a click
// overrides that until another company is shown.
const sectionHasData = computed(() => ({
  contacts: contacts.value.length > 0,
  conversations: openConversations.value.length > 0,
  deals: openDeals.value.length > 0,
  profile:
    Boolean(company.value?.description) || attributeRows.value.length > 0,
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

    <template v-else-if="hasCompany">
      <div class="flex flex-col w-full gap-2 p-5">
        <div class="flex flex-col items-center">
          <Avatar
            :name="company.name || ''"
            :src="company.avatarUrl"
            :size="64"
            hide-offline-status
            class="ring-2 ring-n-brand/20"
          />
        </div>
        <div
          class="flex flex-col items-center w-full min-w-0 gap-1 text-center"
        >
          <div class="flex items-center justify-center w-full min-w-0 gap-2">
            <h3
              class="max-w-full min-w-0 my-0 text-lg font-semibold tracking-tight break-words text-n-slate-12"
            >
              {{ company.name }}
            </h3>
            <div class="flex items-center flex-shrink-0 gap-2">
              <span
                v-if="company.createdAt"
                v-tooltip.left="
                  t('COMPANIES.CONVERSATION_PANEL.CREATED_AT', {
                    time: dynamicTime(company.createdAt),
                  })
                "
                class="text-sm i-lucide-info text-n-slate-10"
              />
              <button
                v-tooltip.top-end="
                  t('COMPANIES.CONVERSATION_PANEL.OPEN_COMPANY')
                "
                type="button"
                class="leading-3"
                @click="openCompany"
              >
                <span class="text-sm i-lucide-external-link text-n-slate-10" />
              </button>
            </div>
          </div>
          <p class="text-[13px] text-n-slate-11 mb-0">{{ subtitle }}</p>
          <div class="flex flex-col items-start w-full gap-2 mt-1">
            <ContactInfoRow
              :href="phone ? `tel:${phone}` : ''"
              :value="phone"
              icon="call"
              emoji="📞"
              :title="t('COMPANIES.CONVERSATION_PANEL.PHONE')"
              show-copy
            />
            <ContactInfoRow
              :href="websiteUrl"
              :value="company.domain || ''"
              icon="globe"
              emoji="🌐"
              :title="t('COMPANIES.CONVERSATION_PANEL.PROFILE.WEBSITE')"
            />
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-3 px-2 pt-3 pb-8">
        <AccordionItem
          :title="
            t('COMPANIES.CONVERSATION_PANEL.SECTIONS.CONTACTS', {
              n: contactsCount,
            })
          "
          :is-open="isSectionOpen('contacts')"
          compact
          @toggle="toggleSection('contacts')"
        >
          <ul class="flex flex-col py-1 m-0 list-none">
            <li v-for="item in contacts.slice(0, PREVIEW_LIMIT)" :key="item.id">
              <button
                type="button"
                class="flex items-center w-full gap-3 px-3 py-2 text-left rounded-lg hover:bg-n-alpha-1"
                @click="openContact(item.id)"
              >
                <Avatar
                  :name="item.name || ''"
                  :src="item.thumbnail"
                  :size="28"
                  rounded-full
                  hide-offline-status
                />
                <span class="flex flex-col flex-1 min-w-0">
                  <span class="text-sm font-medium truncate text-n-slate-12">
                    {{ item.name }}
                  </span>
                  <span
                    v-if="item.email || item.phoneNumber"
                    class="text-xs truncate text-n-slate-11"
                  >
                    {{ item.email || item.phoneNumber }}
                  </span>
                </span>
                <span
                  v-if="item.id === contactId"
                  class="flex-shrink-0 px-2 py-0.5 text-xs font-medium rounded-full bg-n-teal-3 text-n-teal-11"
                >
                  {{ t('COMPANIES.CONVERSATION_PANEL.CURRENT_CONTACT') }}
                </span>
              </button>
            </li>
            <li
              v-if="!contacts.length"
              class="px-3 py-2 text-sm text-n-slate-11"
            >
              {{ t('COMPANIES.CONVERSATION_PANEL.SECTIONS.EMPTY') }}
            </li>
          </ul>
          <button
            v-if="contactsCount > PREVIEW_LIMIT"
            type="button"
            class="px-3 pb-3 text-sm font-medium text-n-blue-text"
            @click="openCompany"
          >
            {{ t('COMPANIES.CONVERSATION_PANEL.VIEW_ALL') }}
          </button>
        </AccordionItem>

        <AccordionItem
          :title="
            t('COMPANIES.CONVERSATION_PANEL.SECTIONS.CONVERSATIONS', {
              n: openConversations.length,
            })
          "
          :is-open="isSectionOpen('conversations')"
          compact
          @toggle="toggleSection('conversations')"
        >
          <ul class="flex flex-col py-1 m-0 list-none">
            <li
              v-for="conversation in openConversations.slice(0, PREVIEW_LIMIT)"
              :key="conversation.id"
            >
              <router-link
                :to="conversationPath(conversation.id)"
                class="flex flex-col gap-0.5 px-3 py-2 rounded-lg hover:bg-n-alpha-1"
              >
                <span class="flex items-center justify-between gap-2">
                  <span class="text-sm font-medium truncate text-n-slate-12">
                    {{ conversation.meta?.sender?.name }}
                  </span>
                  <span class="flex-shrink-0 text-xs text-n-slate-10">
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
            <li
              v-if="!openConversations.length"
              class="px-3 py-2 text-sm text-n-slate-11"
            >
              {{ t('COMPANIES.CONVERSATION_PANEL.SECTIONS.EMPTY') }}
            </li>
          </ul>
        </AccordionItem>

        <AccordionItem
          v-if="isCrmDealsEnabled"
          :title="
            t('COMPANIES.CONVERSATION_PANEL.SECTIONS.DEALS', {
              n: openDeals.length,
            })
          "
          :is-open="isSectionOpen('deals')"
          compact
          @toggle="toggleSection('deals')"
        >
          <p
            v-if="openDeals.length"
            class="px-3 pt-2 mb-0 text-xs text-n-slate-11"
          >
            {{
              t('COMPANIES.CONVERSATION_PANEL.DEALS_TOTAL', {
                value: formatVND(openDealsValue),
              })
            }}
          </p>
          <ul class="flex flex-col py-1 m-0 list-none">
            <li
              v-for="deal in openDeals.slice(0, PREVIEW_LIMIT)"
              :key="deal.id"
              class="flex items-center justify-between gap-2 px-3 py-2"
            >
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ deal.name }}
              </span>
              <span
                v-if="deal.value"
                class="flex-shrink-0 text-xs font-medium text-n-slate-11 tabular-nums"
              >
                {{ formatVND(deal.value) }}
              </span>
            </li>
            <li
              v-if="!openDeals.length"
              class="px-3 py-2 text-sm text-n-slate-11"
            >
              {{ t('COMPANIES.CONVERSATION_PANEL.SECTIONS.EMPTY') }}
            </li>
          </ul>
        </AccordionItem>

        <AccordionItem
          :title="t('COMPANIES.CONVERSATION_PANEL.PROFILE.TITLE')"
          :is-open="isSectionOpen('profile')"
          compact
          @toggle="toggleSection('profile')"
        >
          <div class="flex flex-col gap-3 px-3 py-3">
            <p v-if="company.description" class="mb-0 text-sm text-n-slate-12">
              {{ company.description }}
            </p>
            <dl v-if="attributeRows.length" class="flex flex-col gap-3 m-0">
              <div
                v-for="row in attributeRows"
                :key="row.key"
                class="flex flex-col gap-0.5 text-sm"
              >
                <dt class="text-xs text-n-slate-11">{{ row.label }}</dt>
                <dd class="m-0 min-w-0 break-words text-n-slate-12">
                  {{ row.value }}
                </dd>
              </div>
            </dl>
            <p
              v-if="!sectionHasData.profile"
              class="mb-0 text-sm text-n-slate-11"
            >
              {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.EMPTY') }}
            </p>
          </div>
        </AccordionItem>
      </div>
    </template>

    <p v-else class="px-4 py-8 text-sm text-center text-n-slate-11">
      {{
        companyId
          ? t('COMPANIES.CONVERSATION_PANEL.EMPTY')
          : t('CONVERSATION.SIDEBAR.NO_COMPANY')
      }}
    </p>
  </div>
</template>
