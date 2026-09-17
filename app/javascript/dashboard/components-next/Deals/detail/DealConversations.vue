<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import DealsAPI from 'dashboard/api/deals';
import ContactAPI from 'dashboard/api/contacts';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  deal: { type: Object, required: true },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const conversations = ref([]);
const contactConversations = ref([]);
const isLoading = ref(false);

const linkOptions = computed(() => {
  const linkedIds = conversations.value.map(conversation => conversation.id);
  return contactConversations.value
    .filter(conversation => !linkedIds.includes(conversation.id))
    .map(conversation => ({
      value: conversation.id,
      label: `#${conversation.id} · ${conversation.messages?.[0]?.content || ''}`,
    }));
});

const loadConversations = async () => {
  isLoading.value = true;
  try {
    const [{ data }, contactResponse] = await Promise.all([
      DealsAPI.getConversations(props.deal.id),
      props.deal.contact
        ? ContactAPI.getConversations(props.deal.contact.id)
        : null,
    ]);
    conversations.value = camelcaseKeys(data.payload, { deep: true });
    contactConversations.value = contactResponse
      ? camelcaseKeys(contactResponse.data.payload, { deep: true })
      : [];
  } catch {
    useAlert(t('DEALS.DETAIL.CONVERSATIONS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const linkConversation = async conversationId => {
  if (!conversationId) return;
  try {
    await DealsAPI.linkConversation(props.deal.id, conversationId);
    await loadConversations();
  } catch {
    useAlert(t('DEALS.DETAIL.CONVERSATIONS.LINK_ERROR'));
  }
};

const unlinkConversation = async conversationId => {
  try {
    await DealsAPI.unlinkConversation(props.deal.id, conversationId);
    conversations.value = conversations.value.filter(
      conversation => conversation.id !== conversationId
    );
  } catch {
    useAlert(t('DEALS.DETAIL.CONVERSATIONS.UNLINK_ERROR'));
  }
};

const openConversation = conversationId => {
  router.push(
    frontendURL(
      conversationUrl({ accountId: route.params.accountId, id: conversationId })
    )
  );
};

watch(
  () => [props.deal.id, props.deal.contact?.id],
  loadConversations,
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <ComboBox
      v-if="deal.contact"
      model-value=""
      :options="linkOptions"
      :placeholder="t('DEALS.DETAIL.CONVERSATIONS.LINK_PLACEHOLDER')"
      :empty-state="t('DEALS.DETAIL.CONVERSATIONS.NO_CONTACT_CONVERSATIONS')"
      @update:model-value="linkConversation"
    />
    <p v-else class="mb-0 text-sm text-n-slate-11">
      {{ t('DEALS.DETAIL.CONVERSATIONS.NO_CONTACT') }}
    </p>
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner :size="20" />
    </div>
    <p
      v-else-if="!conversations.length"
      class="mb-0 text-sm text-n-slate-11"
    >
      {{ t('DEALS.DETAIL.CONVERSATIONS.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col gap-2 list-none">
      <li
        v-for="conversation in conversations"
        :key="conversation.id"
        class="flex items-center gap-2 p-2 text-sm rounded-lg bg-n-alpha-1"
      >
        <button
          type="button"
          class="flex flex-col flex-1 min-w-0 gap-0.5 text-start"
          @click="openConversation(conversation.id)"
        >
          <span class="font-medium text-n-slate-12">
            #{{ conversation.id }} · {{ conversation.meta?.sender?.name }}
          </span>
          <span class="truncate text-n-slate-11">
            {{ conversation.messages?.[0]?.content }}
          </span>
        </button>
        <Button
          icon="i-lucide-unlink"
          color="slate"
          variant="ghost"
          size="xs"
          @click="unlinkConversation(conversation.id)"
        />
      </li>
    </ul>
  </div>
</template>
