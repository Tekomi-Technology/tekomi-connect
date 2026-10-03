<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ContactAPI from 'dashboard/api/contacts';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

// Fetched directly instead of reading the shared contact store: websocket
// events merge sender payloads (which carry no contact_inboxes) into that
// store, resurrecting stale channel entries on top of fresh ones.
const channels = ref([]);
const isLoading = ref(true);

const prettyChannelType = type =>
  (type || '').replace('Channel::', '').replace(/_/g, ' ');

const fetchChannels = async () => {
  isLoading.value = true;
  try {
    const { data } = await ContactAPI.show(props.selectedContact.id);
    channels.value = data.payload?.contact_inboxes || [];
  } catch (error) {
    channels.value = [];
  } finally {
    isLoading.value = false;
  }
};

onMounted(fetchChannels);
</script>

<template>
  <div class="flex flex-col gap-2 px-6 py-4">
    <p class="text-sm font-medium text-n-slate-12">
      {{ $t('CONTACTS_LAYOUT.SIDEBAR.CHANNELS.TITLE') }}
    </p>
    <p v-if="isLoading" class="text-xs text-n-slate-11">
      {{ $t('CONTACTS_LAYOUT.SIDEBAR.CHANNELS.LOADING') }}
    </p>
    <p v-else-if="!channels.length" class="text-xs text-n-slate-11">
      {{ $t('CONTACTS_LAYOUT.SIDEBAR.CHANNELS.EMPTY') }}
    </p>
    <div
      v-for="contactInbox in channels"
      :key="contactInbox.id"
      class="flex flex-col gap-0.5 px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12 truncate">
          {{ contactInbox.inbox?.name }}
        </span>
        <span class="text-xs text-n-slate-11 flex-shrink-0">
          {{ prettyChannelType(contactInbox.inbox?.channel_type) }}
        </span>
      </div>
      <span class="text-xs text-n-slate-11 truncate">
        {{ contactInbox.source_id }}
      </span>
    </div>
  </div>
</template>
