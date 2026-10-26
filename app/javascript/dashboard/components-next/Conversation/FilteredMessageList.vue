<script setup>
import { ref, onMounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import MessageApi from 'dashboard/api/inbox/message';
import MessageList from 'next/message/MessageList.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
  senderKind: { type: String, required: true },
  currentUserId: { type: Number, required: true },
  isAnEmailChannel: { type: Boolean, default: false },
  inboxSupportsReplyTo: {
    type: Object,
    default: () => ({ incoming: false, outgoing: false }),
  },
});

const PAGE_SIZE = 20;

const { t } = useI18n();

const listRef = ref(null);
const messages = ref([]);
const isLoading = ref(false);
const hasMore = ref(false);
const hasError = ref(false);

const fetchMessages = async () => {
  isLoading.value = true;
  hasError.value = false;
  try {
    const { data } = await MessageApi.getBySenderKind({
      conversationId: props.conversationId,
      senderKind: props.senderKind,
      before: messages.value[0]?.id,
    });
    messages.value = [...data.payload, ...messages.value];
    hasMore.value = data.payload.length === PAGE_SIZE;
  } catch (error) {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  await fetchMessages();
  await nextTick();
  const el = listRef.value?.$el;
  if (el) el.scrollTop = el.scrollHeight;
});
</script>

<template>
  <MessageList
    ref="listRef"
    class="flex flex-col flex-grow flex-shrink h-full pb-4 m-0 overflow-y-auto basis-px"
    :current-user-id="currentUserId"
    :is-an-email-channel="isAnEmailChannel"
    :inbox-supports-reply-to="inboxSupportsReplyTo"
    :messages="messages"
  >
    <template #beforeAll>
      <li class="flex items-center justify-center py-3 list-none first:mt-auto">
        <Spinner v-if="isLoading" class="text-n-brand" />
        <Button
          v-else-if="hasMore"
          :label="t('CONVERSATION.SENDER_FILTER.LOAD_MORE')"
          icon="i-lucide-arrow-up"
          slate
          faded
          xs
          @click="fetchMessages"
        />
        <p v-else-if="hasError" class="mb-0 text-xs text-n-ruby-11">
          {{ t('CONVERSATION.SENDER_FILTER.ERROR') }}
        </p>
        <p v-else-if="!messages.length" class="mb-0 text-xs text-n-slate-11">
          {{ t('CONVERSATION.SENDER_FILTER.EMPTY') }}
        </p>
      </li>
    </template>
  </MessageList>
</template>
