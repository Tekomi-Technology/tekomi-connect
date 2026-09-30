<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  contacts: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const openContact = contactId => {
  router.push({
    name: 'contacts_edit',
    params: { accountId: route.params.accountId, contactId },
  });
};
</script>

<template>
  <div
    v-if="isLoading && !contacts.length"
    class="flex items-center justify-center py-10 text-n-slate-11"
  >
    <Spinner />
  </div>

  <div v-else-if="contacts.length" class="flex flex-col divide-y divide-n-weak">
    <button
      v-for="contact in contacts"
      :key="contact.id"
      type="button"
      class="flex items-center w-full gap-3 px-4 py-3 text-left hover:bg-n-alpha-1"
      @click="openContact(contact.id)"
    >
      <Avatar
        :name="contact.name || ''"
        :src="contact.thumbnail"
        :size="32"
        rounded-full
        hide-offline-status
      />
      <div class="flex flex-col min-w-0 gap-0.5">
        <span class="text-sm font-medium truncate text-n-slate-12">
          {{ contact.name || t('COMPANIES.DETAIL.CONTACTS.UNNAMED_CONTACT') }}
        </span>
        <span
          v-if="contact.email || contact.phoneNumber"
          class="text-xs truncate text-n-slate-11"
        >
          {{ contact.email || contact.phoneNumber }}
        </span>
      </div>
    </button>
  </div>

  <p
    v-else
    class="px-4 py-8 mx-4 text-sm text-center border border-dashed rounded-xl border-n-strong text-n-slate-11"
  >
    {{ t('COMPANIES.CONVERSATION_PANEL.CONTACTS.EMPTY') }}
  </p>
</template>
