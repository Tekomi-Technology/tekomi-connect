<script setup>
import { computed, ref, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const POLL_INTERVAL_MS = 5000;
const POLL_TIMEOUT_MS = 180000;

const { t } = useI18n();
const store = useStore();
const contactGetter = useMapGetter('contacts/getContact');
const contact = computed(() => contactGetter.value(props.contactId));
const additionalAttributes = computed(
  () => contact.value.additional_attributes || {}
);

const perfexId = computed(
  () => additionalAttributes.value.external?.perfex_contact_id
);
const crmInfo = computed(() => additionalAttributes.value.crm || {});
const hasFailed = computed(
  () => !!crmInfo.value.match_failed_at && !perfexId.value
);

const isLoading = ref(false);
const isForceSyncing = ref(false);
let pollTimer = null;

const isMatched = () =>
  !!contact.value?.additional_attributes?.external?.perfex_contact_id;

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const pollUntilMatched = () => {
  const startedAt = Date.now();
  pollTimer = setInterval(async () => {
    if (Date.now() - startedAt > POLL_TIMEOUT_MS) {
      stopPolling();
      isForceSyncing.value = false;
      useAlert(
        t(
          'CONVERSATION_SIDEBAR.CRM_INFO.FORCE_SYNC_TIMEOUT'
        )
      );
      return;
    }
    try {
      await store.dispatch('contacts/matchCrm', props.contactId);
      if (isMatched()) {
        stopPolling();
        isForceSyncing.value = false;
      }
    } catch (error) {
      // keep polling; the background sync may not be finished yet
    }
  }, POLL_INTERVAL_MS);
};

const reload = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('contacts/matchCrm', props.contactId);
  } catch (error) {
    useAlert(error.message);
  } finally {
    isLoading.value = false;
  }
};

const forceSync = async () => {
  isForceSyncing.value = true;
  try {
    await store.dispatch('contacts/crmForceSync');
    useAlert(
      t('CONVERSATION_SIDEBAR.CRM_INFO.FORCE_SYNC_STARTED')
    );
    stopPolling();
    pollUntilMatched();
  } catch (error) {
    useAlert(error.message);
    isForceSyncing.value = false;
  }
};

onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div v-if="perfexId">
      <p class="text-sm font-medium text-n-slate-12">
        {{ crmInfo.name }}
      </p>
      <p class="text-xs text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.USERID_LABEL') }}: {{ perfexId }}
      </p>
    </div>
    <div v-else>
      <p v-if="hasFailed" class="mb-2 text-sm text-n-ruby-11">
        {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.NOT_FOUND') }}
      </p>
      <div class="flex items-center gap-2">
        <NextButton
          faded
          slate
          size="sm"
          :is-loading="isLoading"
          :label="$t('CONVERSATION_SIDEBAR.CRM_INFO.RELOAD')"
          @click="reload"
        />
        <NextButton
          faded
          slate
          size="sm"
          :is-loading="isForceSyncing"
          :label="$t('CONVERSATION_SIDEBAR.CRM_INFO.FORCE_SYNC')"
          @click="forceSync"
        />
      </div>
    </div>
  </div>
</template>
