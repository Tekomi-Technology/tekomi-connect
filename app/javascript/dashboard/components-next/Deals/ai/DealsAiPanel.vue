<script setup>
import { ref, nextTick, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import DealAssistantAPI from 'dashboard/api/dealAssistant';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  dealId: { type: Number, default: null },
  pipelineId: { type: Number, default: null },
});

const emit = defineEmits(['close']);

const outsideClickHandler = [
  () => emit('close'),
  { ignore: ['#toggleDealsAiButton', '#toggleDealDetailAiButton'] },
];

const HISTORY_LIMIT = 10;

const { t } = useI18n();
const question = ref('');
const history = ref([]);
const isAsking = ref(false);
const messagesRef = useTemplateRef('messagesRef');

const scrollToBottom = () => {
  nextTick(() => {
    if (messagesRef.value) {
      messagesRef.value.scrollTop = messagesRef.value.scrollHeight;
    }
  });
};

const ask = async () => {
  const message = question.value.trim();
  if (!message || isAsking.value) return;

  question.value = '';
  history.value.push({ role: 'user', content: message });
  isAsking.value = true;
  scrollToBottom();

  try {
    const { data } = await DealAssistantAPI.ask({
      message,
      dealId: props.dealId,
      pipelineId: props.pipelineId,
      previousHistory: history.value.slice(-HISTORY_LIMIT - 1, -1),
    });
    history.value.push({ role: 'assistant', content: data.response });
  } catch (error) {
    history.value.push({
      role: 'assistant',
      content:
        error?.response?.data?.error || t('DEALS.AI.ERROR'),
    });
  } finally {
    isAsking.value = false;
    scrollToBottom();
  }
};
</script>

<template>
  <div
    v-on-click-outside="outsideClickHandler"
    class="z-40 flex flex-col w-[calc(100vw-2rem)] max-w-md gap-3 p-4 border shadow-lg bg-n-alpha-3 backdrop-blur-[100px] border-n-weak rounded-xl"
  >
    <div class="flex items-center gap-2">
      <Icon icon="i-woot-tekomi" class="size-4 text-n-brand" />
      <h3 class="mb-0 text-sm font-medium text-n-slate-12">
        {{ t('DEALS.AI.TITLE') }}
      </h3>
    </div>

    <div
      v-if="history.length"
      ref="messagesRef"
      class="flex flex-col gap-3 overflow-y-auto max-h-80"
    >
      <div
        v-for="(entry, index) in history"
        :key="index"
        class="flex flex-col gap-1 text-sm"
      >
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{
            entry.role === 'user'
              ? t('DEALS.AI.YOU')
              : t('DEALS.AI.ASSISTANT')
          }}
        </span>
        <p class="mb-0 whitespace-pre-line text-n-slate-12">
          {{ entry.content }}
        </p>
      </div>
      <div v-if="isAsking" class="flex justify-center py-2">
        <Spinner :size="16" />
      </div>
    </div>
    <p v-else class="mb-0 text-sm text-n-slate-11">
      {{ t('DEALS.AI.PLACEHOLDER_HINT') }}
    </p>

    <div class="flex items-end gap-2">
      <textarea
        v-model="question"
        rows="2"
        :placeholder="t('DEALS.AI.INPUT_PLACEHOLDER')"
        class="flex-1 px-3 py-2 mb-0 text-sm rounded-lg resize-none reset-base bg-n-alpha-1 text-n-slate-12"
        @keydown.enter.exact.prevent="ask"
      />
      <Button
        icon="i-lucide-send"
        size="sm"
        :disabled="!question.trim() || isAsking"
        :is-loading="isAsking"
        @click="ask"
      />
    </div>
  </div>
</template>
