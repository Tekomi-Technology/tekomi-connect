<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useCompaniesStore } from 'dashboard/stores/companies';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  companyId: { type: [Number, String], default: null },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const companiesStore = useCompaniesStore();

const companyAttributes = useMapGetter('attributes/getCompanyAttributes');

const company = computed(() =>
  companiesStore.getRecord(Number(props.companyId))
);
const hasCompany = computed(() => Boolean(company.value?.id));
const isLoadingCompany = computed(
  () => companiesStore.getUIFlags.fetchingItem && !hasCompany.value
);

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

const hasProfile = computed(
  () =>
    Boolean(company.value?.description) ||
    Boolean(websiteUrl.value) ||
    attributeRows.value.length > 0
);

const openCompany = () => {
  router.push({
    name: 'companies_dashboard_show',
    params: { accountId: route.params.accountId, companyId: props.companyId },
  });
};

watch(
  () => Number(props.companyId),
  id => {
    if (id) companiesStore.show(id);
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
      <div class="flex items-start gap-3 px-4 py-3 border-b border-n-weak">
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

      <section class="flex flex-col gap-3 px-4 py-4">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.TITLE') }}
        </h4>
        <p v-if="company.description" class="mb-0 text-sm text-n-slate-11">
          {{ company.description }}
        </p>
        <dl v-if="hasProfile" class="flex flex-col gap-3 m-0">
          <div v-if="websiteUrl" class="flex flex-col gap-0.5 text-sm">
            <dt class="text-xs text-n-slate-11">
              {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.WEBSITE') }}
            </dt>
            <dd class="m-0 min-w-0">
              <a
                :href="websiteUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1 break-all text-n-blue-text"
              >
                {{ company.domain }}
                <Icon icon="i-lucide-external-link" class="size-3 shrink-0" />
              </a>
            </dd>
          </div>
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
        <p v-else class="mb-0 text-sm text-n-slate-11">
          {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.EMPTY') }}
        </p>
      </section>
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
