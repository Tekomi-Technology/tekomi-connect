<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const channels = computed(() => props.selectedContact?.contact_inboxes || []);

const prettyChannelType = type =>
  (type || '').replace('Channel::', '').replace(/_/g, ' ');
</script>

<template>
  <div class="flex flex-col gap-2 px-6 py-4">
    <p class="text-sm font-medium text-n-slate-12">
      {{ $t('CONTACTS_LAYOUT.SIDEBAR.CHANNELS.TITLE') }}
    </p>
    <p
      v-if="!channels.length"
      class="text-xs text-n-slate-11"
    >
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
