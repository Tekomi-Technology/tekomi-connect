<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

// The worker fixes the proxy when a session logs in, so saving the switch makes it reconnect
// this inbox's live Zalo session through (or around) the proxy straight away.
const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const proxyEnabled = computed({
  get: () => props.inbox.zalo_proxy_enabled !== false,
  set: async value => {
    try {
      await store.dispatch('inboxes/updateInbox', {
        id: props.inbox.id,
        formData: false,
        channel: { proxy_enabled: value },
      });
      useAlert(t('INBOX_MGMT.ZALO_PERSONAL_PROXY.SAVED'));
    } catch {
      useAlert(t('INBOX_MGMT.ZALO_PERSONAL_PROXY.ERROR'));
    }
  },
});
</script>

<template>
  <div class="flex items-start gap-3">
    <ToggleSwitch v-model="proxyEnabled" class="mt-0.5" />
    <div class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{
          proxyEnabled
            ? $t('INBOX_MGMT.ZALO_PERSONAL_PROXY.ENABLED')
            : $t('INBOX_MGMT.ZALO_PERSONAL_PROXY.DISABLED')
        }}
      </span>
      <span class="text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ZALO_PERSONAL_PROXY.HINT') }}
      </span>
    </div>
  </div>
</template>
