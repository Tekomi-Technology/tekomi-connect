<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ZaloPersonalChannel from 'dashboard/api/channel/zaloPersonalChannel';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

// A Zalo QR code stops being scannable after a couple of minutes, so the screen offers a
// fresh one rather than leaving a dead image on screen.
const POLL_INTERVAL = 2000;

const qrImage = ref('');
const isStarting = ref(false);
const isExpired = ref(false);
const errorCode = ref('');

let pollTimer = null;

const stopPolling = () => {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
};

onBeforeUnmount(stopPolling);

const isWaitingForScan = computed(
  () => Boolean(qrImage.value) && !isExpired.value && !errorCode.value
);

const errorMessage = computed(() => {
  if (!errorCode.value) return '';
  if (errorCode.value === 'account_mismatch')
    return t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.ACCOUNT_MISMATCH');
  if (errorCode.value === 'declined')
    return t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.DECLINED');
  return t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.GENERIC');
});

const expire = () => {
  stopPolling();
  qrImage.value = '';
  isExpired.value = true;
};

const fail = code => {
  stopPolling();
  qrImage.value = '';
  errorCode.value = code;
};

const poll = async qrSessionId => {
  try {
    const { data } = await ZaloPersonalChannel.getAuthorization(qrSessionId);
    if (data.status === 'success') {
      stopPolling();
      router.replace({
        name: 'settings_inboxes_add_agents',
        params: { page: 'new', inbox_id: data.inbox_id },
      });
    } else if (data.status === 'expired') {
      expire();
    } else if (data.status === 'error') {
      fail(data.error);
    }
  } catch (error) {
    fail('generic');
  }
};

const connect = async () => {
  isStarting.value = true;
  isExpired.value = false;
  errorCode.value = '';
  try {
    // channel_id is present only when re-authenticating an inbox whose session expired.
    const { data } = await ZaloPersonalChannel.startAuthorization(
      route.query.channel_id
    );
    qrImage.value = data.qr_image;
    pollTimer = setInterval(() => poll(data.qr_session_id), POLL_INTERVAL);
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.ERROR.GENERIC')
    );
  } finally {
    isStarting.value = false;
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.DESC')"
    />

    <div class="flex flex-col items-start gap-4 mt-4">
      <p
        v-if="!qrImage"
        class="text-sm text-n-slate-11 max-w-lg"
        :class="{ 'text-n-ruby-11': errorMessage }"
      >
        {{
          errorMessage ||
          (isExpired
            ? $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.EXPIRED')
            : $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.INTRO'))
        }}
      </p>

      <template v-if="isWaitingForScan">
        <img
          :src="qrImage"
          :alt="$t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.ALT')"
          class="w-56 h-56 rounded-lg border border-n-weak bg-white p-2"
        />
        <p class="text-sm text-n-slate-11 max-w-lg">
          {{ $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.INSTRUCTIONS') }}
        </p>
      </template>

      <NextButton
        v-if="!isWaitingForScan"
        :is-loading="isStarting"
        solid
        blue
        :label="
          isExpired || errorCode
            ? $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.QR.REGENERATE')
            : $t('INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.SUBMIT_BUTTON')
        "
        @click="connect"
      />
    </div>
  </div>
</template>
