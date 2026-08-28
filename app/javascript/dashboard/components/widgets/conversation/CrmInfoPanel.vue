<script setup>
import { computed, ref, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ContactAPI from 'dashboard/api/contacts';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const POLL_INTERVAL_MS = 5000;
const POLL_TIMEOUT_MS = 180000;
const SEARCH_DEBOUNCE_MS = 300;

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
const mappedContactName = computed(
  () => additionalAttributes.value.mapped_contact_name || ''
);
const hasFailed = computed(
  () => !!crmInfo.value.match_failed_at && !perfexId.value
);

const isForceSyncing = ref(false);
const showAssignPanel = ref(false);
const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
let pollTimer = null;
let searchDebounceTimer = null;

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
      useAlert(t('CONVERSATION_SIDEBAR.CRM_INFO.FORCE_SYNC_TIMEOUT'));
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

const forceSync = async () => {
  isForceSyncing.value = true;
  try {
    await store.dispatch('contacts/crmForceSync');
    useAlert(t('CONVERSATION_SIDEBAR.CRM_INFO.FORCE_SYNC_STARTED'));
    stopPolling();
    pollUntilMatched();
  } catch (error) {
    useAlert(error.message);
    isForceSyncing.value = false;
  }
};

const searchContacts = async query => {
  isSearching.value = true;
  try {
    const {
      data: { payload },
    } = await ContactAPI.search(query);
    searchResults.value = payload.filter(item => item.id !== Number(props.contactId));
  } catch (error) {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
};

const onSearchInput = () => {
  clearTimeout(searchDebounceTimer);
  if (!searchQuery.value.trim()) {
    searchResults.value = [];
    return;
  }
  searchDebounceTimer = setTimeout(
    () => searchContacts(searchQuery.value.trim()),
    SEARCH_DEBOUNCE_MS
  );
};

const assignTo = async targetContact => {
  try {
    await store.dispatch('contacts/mapContact', {
      contactId: props.contactId,
      targetContactId: targetContact.id,
    });
    showAssignPanel.value = false;
    searchQuery.value = '';
    searchResults.value = [];
  } catch (error) {
    useAlert(error.message);
  }
};

const unassign = async () => {
  try {
    await store.dispatch('contacts/unmapContact', { contactId: props.contactId });
  } catch (error) {
    useAlert(error.message);
  }
};

onBeforeUnmount(() => {
  stopPolling();
  clearTimeout(searchDebounceTimer);
});
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
      <p class="mb-2 text-xs font-medium text-n-amber-11">
        {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.UNIDENTIFIED') }}
      </p>
      <p v-if="hasFailed" class="mb-2 text-sm text-n-ruby-11">
        {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.NOT_FOUND') }}
      </p>
      <div
        v-if="mappedContactName"
        class="flex items-center justify-between gap-2 mb-2"
      >
        <p class="text-sm truncate">
          {{ $t('CONVERSATION_SIDEBAR.CRM_INFO.ASSIGNED_TO') }}:
          <span class="font-medium">{{ mappedContactName }}</span>
        </p>
        <NextButton
          faded
          ruby
          size="sm"
          :label="$t('CONVERSATION_SIDEBAR.CRM_INFO.UNASSIGN')"
          @click="unassign"
        />
      </div>
      <div class="flex items-center gap-2">
        <NextButton
          faded
          slate
          size="sm"
          :is-loading="isForceSyncing"
          :label="$t('CONVERSATION_SIDEBAR.CRM_INFO.FORCE_SYNC')"
          @click="forceSync"
        />
        <NextButton
          v-if="!mappedContactName"
          faded
          slate
          size="sm"
          :label="$t('CONVERSATION_SIDEBAR.CRM_INFO.ASSIGN_TO_CUSTOMER')"
          @click="showAssignPanel = !showAssignPanel"
        />
      </div>
      <div v-if="showAssignPanel" class="mt-2">
        <Input
          v-model="searchQuery"
          type="search"
          :placeholder="
            $t('CONVERSATION_SIDEBAR.CRM_INFO.ASSIGN_SEARCH_PLACEHOLDER')
          "
          @input="onSearchInput"
        />
        <ul class="mt-1 max-h-48 overflow-y-auto">
          <li
            v-for="result in searchResults"
            :key="result.id"
            class="px-2 py-1.5 rounded-md hover:bg-n-alpha-2 cursor-pointer"
            @click="assignTo(result)"
          >
            <p class="text-sm">{{ result.name }}</p>
            <p class="text-xs text-n-slate-11 truncate">
              {{ result.phone_number || result.email }}
            </p>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>
