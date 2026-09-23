<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { formatDuration } from 'shared/helpers/timeHelper';
import { useMessageContext } from '../provider.js';
import phoneCallsAPI from 'dashboard/api/phoneCalls';
import analyzeCallRecording from 'dashboard/api/callEmotionAnalysis';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import AudioChip from 'next/message/chips/Audio.vue';
import PhoneCallDetailsDialog from './PhoneCallDetailsDialog.vue';

const { t } = useI18n();
const store = useStore();
const { contentAttributes, conversationId } = useMessageContext();

const call = computed(() => contentAttributes.value?.data || {});
const direction = computed(() => call.value.direction);
const status = computed(() => call.value.status || 'ringing');
const isOutbound = computed(() => direction.value === 'outbound');
const isFailed = computed(() =>
  ['missed', 'busy', 'no_answer', 'rejected', 'cancelled', 'failed'].includes(
    status.value
  )
);

const title = computed(() => {
  if (status.value === 'completed')
    return t('CONVERSATION.PHONE_CALL.COMPLETED');
  if (status.value === 'in_progress')
    return t('CONVERSATION.PHONE_CALL.IN_PROGRESS');
  if (status.value === 'missed') return t('CONVERSATION.PHONE_CALL.MISSED');
  if (status.value === 'busy') return t('CONVERSATION.PHONE_CALL.BUSY');
  if (status.value === 'no_answer')
    return t('CONVERSATION.PHONE_CALL.NO_ANSWER');
  if (status.value === 'rejected') return t('CONVERSATION.PHONE_CALL.REJECTED');
  if (status.value === 'cancelled')
    return t('CONVERSATION.PHONE_CALL.CANCELLED');
  if (status.value === 'failed') return t('CONVERSATION.PHONE_CALL.FAILED');
  return isOutbound.value
    ? t('CONVERSATION.PHONE_CALL.OUTBOUND')
    : t('CONVERSATION.PHONE_CALL.INBOUND');
});

const details = computed(() => {
  const duration =
    call.value.durationSeconds ?? call.value.duration_seconds ?? null;
  return [
    call.value.customerNumber || call.value.customer_number,
    call.value.agentName || call.value.agent_name,
    duration ? formatDuration(duration) : null,
  ]
    .filter(Boolean)
    .join(' · ');
});

const iconName = computed(() => {
  if (isFailed.value) return 'i-ph-phone-x-bold';
  return isOutbound.value
    ? 'i-ph-phone-outgoing-bold'
    : 'i-ph-phone-incoming-bold';
});

const iconClass = computed(() => {
  if (isFailed.value) return 'bg-n-ruby-3 text-n-ruby-10';
  if (['ringing', 'in_progress'].includes(status.value))
    return 'bg-n-teal-3 text-n-teal-11';
  return 'bg-n-alpha-2 text-n-slate-12';
});

const recordingAttachment = computed(() => {
  const recordingUrl = call.value.recordingUrl || call.value.recording_url;
  if (!recordingUrl) return null;
  return {
    dataUrl: recordingUrl,
    fileType: 'audio',
    extension: 'wav',
    // Dashboard authentication is header-based. Native <audio> requests
    // cannot carry those headers, so AudioChip fetches these through axios.
    requiresAuth: recordingUrl.startsWith('/api/'),
  };
});

const callbotSummary = computed(
  () => call.value.callbotSummary || call.value.callbot_summary
);
const callbotOutcome = computed(
  () => call.value.callbotOutcome || call.value.callbot_outcome
);
const callbotAnalysisStatus = computed(
  () => call.value.callbotAnalysisStatus || call.value.callbot_analysis_status
);
const isCallbot = computed(
  () =>
    Boolean(callbotSummary.value) ||
    Boolean(callbotOutcome.value) ||
    Boolean(callbotAnalysisStatus.value)
);

const detailsDialogRef = ref(null);
const callDetails = ref(null);
const isLoadingDetails = ref(false);
const hasDetailsError = ref(false);
const isAnalyzingEmotion = ref(false);
const emotionResult = ref(null);
const emotionAnalysisError = ref('');
const isEmotionNoteSaved = ref(false);
const emotionNoteError = ref(false);
const analyzeEmotionLabel = t(
  'CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.ANALYZE'
);
const analyzingEmotionLabel = t(
  'CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.ANALYZING'
);
const emotionAnalysisButtonLabel = computed(() =>
  isAnalyzingEmotion.value ? analyzingEmotionLabel : analyzeEmotionLabel
);

const negativeEmotions = ['buồn', 'khó chịu', 'gay gắt'];
const hasNegativeEmotion = computed(() =>
  negativeEmotions.includes(emotionResult.value?.emotion)
);

const addEmotionReviewNote = async result => {
  const emotion = result.emotion || result.semantic_emotion?.label;
  if (!negativeEmotions.includes(emotion) || isEmotionNoteSaved.value) return;

  const reason = result.semantic_emotion?.reason || result.reason || '';
  const message = t('CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.NOTE', {
    emotion,
    reason,
  });
  try {
    await store.dispatch('createPendingMessageAndSend', {
      conversationId: conversationId.value,
      message,
      private: true,
    });
    isEmotionNoteSaved.value = true;
  } catch {
    emotionNoteError.value = true;
  }
};

const analyzeEmotion = async () => {
  if (!recordingAttachment.value || isAnalyzingEmotion.value) return;

  isAnalyzingEmotion.value = true;
  emotionAnalysisError.value = '';
  emotionNoteError.value = false;
  try {
    emotionResult.value = await analyzeCallRecording(
      recordingAttachment.value.dataUrl
    );
    await addEmotionReviewNote(emotionResult.value);
  } catch (error) {
    emotionAnalysisError.value = error.message;
  } finally {
    isAnalyzingEmotion.value = false;
  }
};

const loadCallDetails = async () => {
  if (callDetails.value || isLoadingDetails.value) return;

  isLoadingDetails.value = true;
  hasDetailsError.value = false;
  try {
    const phoneCallId = call.value.phoneCallId || call.value.phone_call_id;
    const response = await phoneCallsAPI.show(phoneCallId);
    callDetails.value = response.data;
  } catch {
    hasDetailsError.value = true;
  } finally {
    isLoadingDetails.value = false;
  }
};

const openCallDetails = () => {
  if (!isCallbot.value) return;

  detailsDialogRef.value?.open();
  loadCallDetails();
};
</script>

<template>
  <BaseBubble
    class="!max-w-md !p-3 min-w-[240px]"
    :class="{ 'cursor-pointer': isCallbot }"
    :role="isCallbot ? 'button' : undefined"
    :tabindex="isCallbot ? 0 : undefined"
    hide-meta
    @click="openCallDetails"
    @keydown.enter.prevent="openCallDetails"
    @keydown.space.prevent="openCallDetails"
  >
    <div class="flex w-full flex-col gap-3">
      <div class="flex items-start gap-2.5">
        <div
          class="flex size-11 shrink-0 items-center justify-center rounded-xl"
          :class="iconClass"
        >
          <Icon class="size-4" :icon="iconName" />
        </div>
        <div class="flex min-w-0 flex-1 flex-col self-center">
          <span class="truncate text-sm font-medium leading-tight">
            {{ title }}
          </span>
          <span v-if="details" class="truncate text-sm opacity-75">
            {{ details }}
          </span>
          <span
            v-if="callbotSummary"
            class="mt-1 line-clamp-2 text-sm opacity-75"
          >
            {{ callbotSummary }}
          </span>
        </div>
        <Icon
          v-if="isCallbot"
          class="mt-3 size-4 shrink-0 opacity-60"
          icon="i-lucide-chevron-right"
        />
      </div>

      <div v-if="recordingAttachment" @click.stop @keydown.stop>
        <AudioChip
          :attachment="recordingAttachment"
          :show-transcribed-text="false"
        />
        <button
          type="button"
          class="mt-2 inline-flex items-center gap-2 rounded-lg border border-n-strong px-3 py-2 text-sm font-medium hover:bg-n-alpha-2 disabled:cursor-wait disabled:opacity-60"
          :disabled="isAnalyzingEmotion"
          @click.stop="analyzeEmotion"
        >
          <Icon
            :icon="
              isAnalyzingEmotion
                ? 'i-lucide-loader-circle'
                : 'i-lucide-scan-face'
            "
            :class="{ 'animate-spin': isAnalyzingEmotion }"
            class="size-4"
          />
          {{ emotionAnalysisButtonLabel }}
        </button>
        <div
          v-if="emotionResult"
          class="mt-2 rounded-lg p-3 text-sm"
          :class="
            hasNegativeEmotion
              ? 'bg-n-amber-3 text-n-amber-11'
              : 'bg-n-alpha-2 text-n-slate-12'
          "
          aria-live="polite"
        >
          <p class="font-medium">
            {{
              $t('CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.RESULT', {
                emotion: emotionResult.emotion,
              })
            }}
          </p>
          <p v-if="hasNegativeEmotion" class="mt-1">
            {{ $t('CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.REVIEW') }}
          </p>
          <p
            v-if="emotionResult.semantic_emotion?.reason"
            class="mt-1 opacity-80"
          >
            {{ emotionResult.semantic_emotion.reason }}
          </p>
          <p v-if="emotionNoteError" class="mt-1">
            {{ $t('CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.NOTE_ERROR') }}
          </p>
          <p v-else-if="isEmotionNoteSaved" class="mt-1">
            {{ $t('CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS.NOTE_SAVED') }}
          </p>
        </div>
        <p
          v-if="emotionAnalysisError"
          class="mt-2 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ emotionAnalysisError }}
        </p>
      </div>
    </div>

    <PhoneCallDetailsDialog
      v-if="isCallbot"
      ref="detailsDialogRef"
      :details="callDetails"
      :is-loading="isLoadingDetails"
      :has-error="hasDetailsError"
    />
  </BaseBubble>
</template>
