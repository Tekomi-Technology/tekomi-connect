<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const form = reactive({
  name: '',
  wssUrl: '',
  sipDomain: '',
  sipUsername: '',
  sipPassword: '',
  stunUrl: '',
});

const isCreating = computed(
  () => store.getters['inboxes/getUIFlags'].isCreating
);
const isValid = computed(() => {
  return (
    form.name.trim() &&
    form.wssUrl.trim().startsWith('wss://') &&
    form.sipDomain.trim() &&
    form.sipUsername.trim() &&
    form.sipPassword
  );
});

const createChannel = async () => {
  if (!isValid.value) {
    useAlert(t('INBOX_MGMT.ADD.PHONE_CHANNEL.VALIDATION_ERROR'));
    return;
  }

  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: form.name.trim(),
      channel: {
        type: 'phone',
        wss_url: form.wssUrl.trim(),
        sip_domain: form.sipDomain.trim(),
        sip_username: form.sipUsername.trim(),
        sip_password: form.sipPassword,
        stun_url: form.stunUrl.trim() || null,
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.PHONE_CHANNEL.API.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <div class="col-span-6 h-full w-full p-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.PHONE_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.PHONE_CHANNEL.DESC')"
    />

    <form class="flex max-w-xl flex-col gap-4" @submit.prevent="createChannel">
      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.NAME') }}
        <input
          v-model="form.name"
          class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal outline-none focus:border-n-brand"
          type="text"
          autocomplete="off"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.WSS_URL') }}
        <input
          v-model="form.wssUrl"
          class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal outline-none focus:border-n-brand"
          type="url"
          :placeholder="$t('INBOX_MGMT.ADD.PHONE_CHANNEL.WSS_PLACEHOLDER')"
          autocomplete="off"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.SIP_DOMAIN') }}
        <input
          v-model="form.sipDomain"
          class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal outline-none focus:border-n-brand"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.PHONE_CHANNEL.DOMAIN_PLACEHOLDER')"
          autocomplete="off"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.SIP_USERNAME') }}
        <input
          v-model="form.sipUsername"
          class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal outline-none focus:border-n-brand"
          type="text"
          autocomplete="username"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.SIP_PASSWORD') }}
        <input
          v-model="form.sipPassword"
          class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal outline-none focus:border-n-brand"
          type="password"
          autocomplete="new-password"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.PHONE_CHANNEL.STUN_URL') }}
        <input
          v-model="form.stunUrl"
          class="h-10 rounded-lg border border-n-weak bg-n-alpha-2 px-3 font-normal outline-none focus:border-n-brand"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.PHONE_CHANNEL.STUN_PLACEHOLDER')"
          autocomplete="off"
        />
      </label>

      <NextButton
        class="mt-2 self-start"
        type="submit"
        solid
        blue
        :disabled="!isValid"
        :is-loading="isCreating"
        :label="$t('INBOX_MGMT.ADD.PHONE_CHANNEL.SUBMIT_BUTTON')"
      />
    </form>
  </div>
</template>
