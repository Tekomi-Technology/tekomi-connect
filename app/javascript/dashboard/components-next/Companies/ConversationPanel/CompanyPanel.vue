<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useCompaniesStore } from 'dashboard/stores/companies';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import CompanyHistorySidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyHistorySidebar.vue';
import CompanyPanelContacts from './CompanyPanelContacts.vue';
import CompanyPanelDeals from './CompanyPanelDeals.vue';
import CompanyPanelFiles from './CompanyPanelFiles.vue';
import CompanyPanelOverview from './CompanyPanelOverview.vue';

const props = defineProps({
  companyId: { type: [Number, String], required: true },
  contact: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const companiesStore = useCompaniesStore();

const accountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const isCrmDealsEnabled = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_DEALS)
);

const activeTab = ref('overview');

const company = computed(() =>
  companiesStore.getRecord(Number(props.companyId))
);
const uiFlags = computed(() => companiesStore.getUIFlags);
const contactsMeta = computed(() => companiesStore.companyContactsMeta);

const hasCompany = computed(() => Boolean(company.value?.id));
const isLoadingCompany = computed(
  () => uiFlags.value.fetchingItem && !hasCompany.value
);

const tabOptions = computed(() =>
  [
    {
      value: 'overview',
      label: t('COMPANIES.CONVERSATION_PANEL.TABS.OVERVIEW'),
    },
    {
      value: 'contacts',
      label: t('COMPANIES.CONVERSATION_PANEL.TABS.CONTACTS'),
      count: Number(contactsMeta.value.totalCount || 0),
    },
    {
      value: 'conversations',
      label: t('COMPANIES.CONVERSATION_PANEL.TABS.CONVERSATIONS'),
      count: companiesStore.companyConversations.length,
    },
    ...(isCrmDealsEnabled.value
      ? [
          {
            value: 'deals',
            label: t('COMPANIES.CONVERSATION_PANEL.TABS.DEALS'),
            count: companiesStore.companyDeals.length,
          },
        ]
      : []),
    { value: 'files', label: t('COMPANIES.CONVERSATION_PANEL.TABS.FILES') },
  ].map(tab => ({ ...tab, count: tab.count || null }))
);

const activeTabIndex = computed(() =>
  tabOptions.value.findIndex(tab => tab.value === activeTab.value)
);

const loadTab = tab => {
  const id = Number(props.companyId);
  if (!id) return;
  if (tab === 'overview') companiesStore.getCompanyNotes(id);
  if (tab === 'contacts') companiesStore.getCompanyContacts(id);
  if (tab === 'conversations') companiesStore.getCompanyConversations(id);
  if (tab === 'deals') companiesStore.getCompanyDeals(id);
  if (tab === 'files') companiesStore.getCompanyAttachments(id);
};

const goToTab = tab => {
  activeTab.value = tab;
  loadTab(tab);
};

const handleTabChange = tab => goToTab(tab.value);

const openCompany = () => {
  router.push({
    name: 'companies_dashboard_show',
    params: { accountId: route.params.accountId, companyId: props.companyId },
  });
};

watch(
  () => Number(props.companyId),
  async id => {
    companiesStore.resetCompanyDetailState();
    activeTab.value = 'overview';
    if (!id) return;
    await Promise.allSettled([
      companiesStore.show(id),
      companiesStore.getCompanyContacts(id),
      companiesStore.getCompanyNotes(id),
    ]);
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col w-full">
    <div
      v-if="isLoadingCompany"
      class="flex items-center justify-center py-10 text-n-slate-11"
    >
      <Spinner />
    </div>

    <template v-else-if="hasCompany">
      <div class="flex items-start gap-3 px-4 py-3">
        <Avatar
          :name="company.name || ''"
          :src="company.avatarUrl"
          :size="38"
          hide-offline-status
        />
        <div class="flex flex-col min-w-0 gap-0.5">
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ company.name }}
          </span>
          <span class="text-xs truncate text-n-slate-11">
            {{
              t('COMPANIES.CONTACTS_COUNT', {
                n: Number(company.contactsCount || 0),
              })
            }}
          </span>
        </div>
        <Button
          v-tooltip.top-end="t('COMPANIES.CONVERSATION_PANEL.OPEN_COMPANY')"
          icon="i-lucide-external-link"
          slate
          xs
          faded
          class="ms-auto shrink-0"
          @click="openCompany"
        />
      </div>

      <div class="px-4 pb-3">
        <TabBar
          :tabs="tabOptions"
          :initial-active-tab="activeTabIndex"
          @tab-changed="handleTabChange"
        />
      </div>

      <CompanyPanelOverview
        v-if="activeTab === 'overview'"
        :company="company"
        :contact="contact"
        :notes="companiesStore.companyNotes"
        :is-loading-notes="uiFlags.fetchingNotes"
        @view-contacts="goToTab('contacts')"
      />
      <CompanyPanelContacts
        v-else-if="activeTab === 'contacts'"
        :contacts="companiesStore.companyContacts"
        :is-loading="uiFlags.fetchingContacts"
      />
      <CompanyHistorySidebar
        v-else-if="activeTab === 'conversations'"
        :conversations="companiesStore.companyConversations"
        :is-loading="uiFlags.fetchingConversations"
      />
      <CompanyPanelDeals
        v-else-if="activeTab === 'deals'"
        :deals="companiesStore.companyDeals"
        :is-loading="uiFlags.fetchingDeals"
      />
      <CompanyPanelFiles
        v-else-if="activeTab === 'files'"
        :attachments="companiesStore.companyAttachments"
        :is-loading="uiFlags.fetchingAttachments"
      />
    </template>

    <p v-else class="px-4 py-8 text-sm text-center text-n-slate-11">
      {{ t('COMPANIES.CONVERSATION_PANEL.EMPTY') }}
    </p>
  </div>
</template>
