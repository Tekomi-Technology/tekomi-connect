<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CompanyNotesSidebar from 'dashboard/components-next/Companies/CompanyDetail/CompanyNotesSidebar.vue';

const props = defineProps({
  company: { type: Object, default: () => ({}) },
  contact: { type: Object, default: () => ({}) },
  notes: { type: Array, default: () => [] },
  isLoadingNotes: { type: Boolean, default: false },
});

const emit = defineEmits(['viewContacts']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const companyAttributes = useMapGetter('attributes/getCompanyAttributes');

const websiteUrl = computed(() => {
  const { domain } = props.company;
  if (!domain) return '';
  return /^https?:\/\//.test(domain) ? domain : `https://${domain}`;
});

const attributeRows = computed(() => {
  const values = props.company?.customAttributes || {};
  const definitions = companyAttributes.value || [];
  const labelFor = key =>
    definitions.find(attribute => attribute.attributeKey === key)
      ?.attributeDisplayName || key;

  return Object.entries(values)
    .filter(([, value]) => value !== '' && value !== null && value !== undefined)
    .map(([key, value]) => ({
      key,
      label: labelFor(key),
      value: Array.isArray(value) ? value.join(', ') : String(value),
    }));
});

const contactTitle = computed(
  () => props.contact?.custom_attributes?.title || props.contact?.email || ''
);

const openContact = () => {
  if (!props.contact?.id) return;
  router.push({
    name: 'contacts_edit',
    params: { accountId: route.params.accountId, contactId: props.contact.id },
  });
};
</script>

<template>
  <div class="flex flex-col">
    <section class="flex flex-col gap-2 px-4 py-4 border-b border-n-weak">
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.TITLE') }}
      </h4>
      <p v-if="company.description" class="mb-0 text-sm text-n-slate-11">
        {{ company.description }}
      </p>
      <dl class="flex flex-col gap-1 m-0">
        <div v-if="websiteUrl" class="flex items-start gap-2 text-sm">
          <dt class="w-28 shrink-0 text-n-slate-11">
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
          class="flex items-start gap-2 text-sm"
        >
          <dt class="w-28 shrink-0 text-n-slate-11">{{ row.label }}</dt>
          <dd class="m-0 min-w-0 break-words text-n-slate-12">
            {{ row.value }}
          </dd>
        </div>
      </dl>
      <p
        v-if="!company.description && !websiteUrl && !attributeRows.length"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('COMPANIES.CONVERSATION_PANEL.PROFILE.EMPTY') }}
      </p>
    </section>

    <section
      v-if="contact.id"
      class="flex flex-col gap-3 px-4 py-4 border-b border-n-weak"
    >
      <div class="flex items-center justify-between gap-2">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.CONVERSATION_PANEL.CONTACT.TITLE') }}
        </h4>
        <Button
          :label="t('COMPANIES.CONVERSATION_PANEL.CONTACT.VIEW_ALL')"
          link
          slate
          xs
          @click="emit('viewContacts')"
        />
      </div>
      <button
        type="button"
        class="flex items-start w-full gap-3 text-left"
        @click="openContact"
      >
        <Avatar
          :name="contact.name || ''"
          :src="contact.thumbnail"
          :size="36"
          rounded-full
          hide-offline-status
        />
        <div class="flex flex-col min-w-0 gap-0.5">
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ contact.name }}
          </span>
          <span v-if="contactTitle" class="text-xs truncate text-n-slate-11">
            {{ contactTitle }}
          </span>
          <span
            v-if="contact.phone_number"
            class="text-xs truncate text-n-slate-11"
          >
            {{ contact.phone_number }}
          </span>
        </div>
      </button>
    </section>

    <section class="flex flex-col gap-3 py-4">
      <h4 class="px-4 text-sm font-medium text-n-slate-12">
        {{ t('COMPANIES.CONVERSATION_PANEL.NOTES.TITLE') }}
      </h4>
      <CompanyNotesSidebar :notes="notes" :is-loading="isLoadingNotes" />
    </section>
  </div>
</template>
