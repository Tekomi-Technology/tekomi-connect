<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';
import { useI18n } from 'vue-i18n';

import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { useMapGetter } from 'dashboard/composables/store';
import { useSoftphoneStore } from 'dashboard/stores/softphone';

const dialpad = [
  ['1', ''],
  ['2', 'ABC'],
  ['3', 'DEF'],
  ['4', 'GHI'],
  ['5', 'JKL'],
  ['6', 'MNO'],
  ['7', 'PQRS'],
  ['8', 'TUV'],
  ['9', 'WXYZ'],
  ['*', ''],
  ['0', '+'],
  ['#', ''],
];

const inboxes = useMapGetter('inboxes/getInboxes');
const { t } = useI18n();
const phoneInbox = computed(() => {
  return inboxes.value.find(inbox => inbox.channel_type === INBOX_TYPES.PHONE);
});

const softphone = useSoftphoneStore();
const {
  error,
  isActive,
  isIncoming,
  muted,
  registered,
  remoteNumber,
  remoteStream,
  status,
} = storeToRefs(softphone);

const isOpen = ref(false);
const destination = ref('');
const remoteAudio = ref(null);

const statusLabel = computed(() => {
  const labels = {
    idle: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.IDLE'),
    connecting: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.CONNECTING'),
    ready: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.READY'),
    disconnected: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.DISCONNECTED'),
    calling: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.CALLING'),
    ringing: isIncoming.value
      ? t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.INCOMING_RINGING')
      : t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.OUTGOING_RINGING'),
    active: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.ACTIVE'),
    error: t('INBOX_MGMT.ADD.SOFTPHONE.STATUS.ERROR'),
  };
  return labels[status.value] || status.value;
});

watch(
  () => phoneInbox.value?.id,
  inboxId => {
    if (inboxId) softphone.initialize(inboxId);
    else softphone.disconnect();
  },
  { immediate: true }
);

watch(isIncoming, incoming => {
  if (incoming) isOpen.value = true;
});

watch(
  [remoteStream, remoteAudio],
  ([stream, audioElement]) => {
    if (!audioElement) return;

    if (audioElement.srcObject !== stream) {
      audioElement.srcObject = stream || null;
    }
    if (!stream) return;

    audioElement.play().catch(playbackError => {
      // eslint-disable-next-line no-console
      console.warn('[Softphone] Unable to play remote audio:', playbackError);
    });
  },
  { flush: 'post', immediate: true }
);

const appendDigit = digit => {
  if (isActive.value) {
    softphone.sendDTMF(digit);
  } else {
    destination.value += digit;
  }
};

const startCall = () => {
  softphone.call(destination.value);
};

onBeforeUnmount(() => softphone.disconnect());
</script>

<template>
  <div>
    <div
      v-if="phoneInbox"
      class="fixed bottom-5 right-5 z-[1000] flex flex-col items-end gap-3"
    >
      <section
        v-if="isOpen"
        class="w-80 overflow-hidden rounded-2xl border border-n-weak bg-n-solid-2 shadow-xl"
      >
        <header
          class="flex items-center justify-between border-b border-n-weak px-4 py-3"
        >
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-n-slate-12">
              {{ phoneInbox.name }}
            </p>
            <p
              class="text-xs"
              :class="registered ? 'text-n-teal-11' : 'text-n-slate-10'"
            >
              {{ statusLabel }}
            </p>
          </div>
          <button
            class="grid size-8 place-items-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
            type="button"
            :aria-label="$t('INBOX_MGMT.ADD.SOFTPHONE.HIDE')"
            @click="isOpen = false"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </header>

        <div class="flex flex-col gap-4 p-4">
          <div v-if="isIncoming" class="flex flex-col items-center gap-3 py-3">
            <div
              class="grid size-14 place-items-center rounded-full bg-n-brand/10 text-n-brand"
            >
              <span class="i-ri-phone-fill size-7" />
            </div>
            <div class="text-center">
              <p class="text-xs text-n-slate-10">
                {{ $t('INBOX_MGMT.ADD.SOFTPHONE.INCOMING') }}
              </p>
              <p class="text-lg font-semibold text-n-slate-12">
                {{ remoteNumber }}
              </p>
            </div>
            <div class="flex gap-3">
              <button
                class="grid size-11 place-items-center rounded-full bg-n-ruby-9 text-white hover:bg-n-ruby-10"
                type="button"
                :aria-label="$t('INBOX_MGMT.ADD.SOFTPHONE.REJECT')"
                @click="softphone.reject"
              >
                <span class="i-ri-phone-fill size-5 rotate-[135deg]" />
              </button>
              <button
                class="grid size-11 place-items-center rounded-full bg-n-teal-9 text-white hover:bg-n-teal-10"
                type="button"
                :aria-label="$t('INBOX_MGMT.ADD.SOFTPHONE.ANSWER')"
                @click="softphone.answer"
              >
                <span class="i-ri-phone-fill size-5" />
              </button>
            </div>
          </div>

          <div
            v-else-if="softphone.hasSession"
            class="flex flex-col items-center gap-4 py-4"
          >
            <div
              class="grid size-14 place-items-center rounded-full bg-n-brand/10 text-n-brand"
            >
              <span class="i-ri-phone-fill size-7" />
            </div>
            <div class="text-center">
              <p class="text-xs text-n-slate-10">{{ statusLabel }}</p>
              <p class="text-lg font-semibold text-n-slate-12">
                {{ remoteNumber }}
              </p>
            </div>
            <div class="flex gap-3">
              <button
                class="grid size-10 place-items-center rounded-full bg-n-alpha-2 text-n-slate-12"
                type="button"
                :aria-label="
                  muted
                    ? $t('INBOX_MGMT.ADD.SOFTPHONE.UNMUTE')
                    : $t('INBOX_MGMT.ADD.SOFTPHONE.MUTE')
                "
                @click="softphone.toggleMute"
              >
                <span
                  :class="muted ? 'i-lucide-mic-off' : 'i-lucide-mic'"
                  class="size-5"
                />
              </button>
              <button
                class="grid size-11 place-items-center rounded-full bg-n-ruby-9 text-white hover:bg-n-ruby-10"
                type="button"
                :aria-label="$t('INBOX_MGMT.ADD.SOFTPHONE.HANGUP')"
                @click="softphone.hangup"
              >
                <span class="i-ri-phone-fill size-5 rotate-[135deg]" />
              </button>
            </div>
          </div>

          <template v-else>
            <div
              class="flex items-center rounded-xl border border-n-weak bg-n-alpha-1 px-3"
            >
              <input
                v-model="destination"
                class="h-11 min-w-0 flex-1 border-0 bg-transparent text-center text-lg text-n-slate-12 outline-none"
                type="tel"
                inputmode="tel"
                :placeholder="$t('INBOX_MGMT.ADD.SOFTPHONE.DESTINATION')"
                @keyup.enter="startCall"
              />
              <button
                v-if="destination"
                class="grid size-7 place-items-center text-n-slate-10"
                type="button"
                :aria-label="$t('INBOX_MGMT.ADD.SOFTPHONE.BACKSPACE')"
                @click="destination = destination.slice(0, -1)"
              >
                <span class="i-lucide-delete size-4" />
              </button>
            </div>

            <div class="grid grid-cols-3 gap-2">
              <button
                v-for="[digit, letters] in dialpad"
                :key="digit"
                class="flex h-12 flex-col items-center justify-center rounded-xl bg-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-3"
                type="button"
                @click="appendDigit(digit)"
              >
                <span class="text-base font-semibold leading-4">{{
                  digit
                }}</span>
                <span class="text-[9px] tracking-wider text-n-slate-9">{{
                  letters
                }}</span>
              </button>
            </div>

            <button
              class="mx-auto grid size-12 place-items-center rounded-full bg-n-teal-9 text-white hover:bg-n-teal-10 disabled:cursor-not-allowed disabled:opacity-50"
              type="button"
              :aria-label="$t('INBOX_MGMT.ADD.SOFTPHONE.CALL')"
              :disabled="!registered || !destination"
              @click="startCall"
            >
              <span class="i-ri-phone-fill size-6" />
            </button>
          </template>

          <p
            v-if="error"
            class="rounded-lg bg-n-ruby-3 px-3 py-2 text-xs text-n-ruby-11"
          >
            {{ error }}
          </p>
        </div>
      </section>

      <button
        class="grid size-12 place-items-center rounded-full bg-n-brand text-white shadow-lg hover:brightness-110"
        type="button"
        :aria-label="
          isOpen
            ? $t('INBOX_MGMT.ADD.SOFTPHONE.CLOSE')
            : $t('INBOX_MGMT.ADD.SOFTPHONE.OPEN')
        "
        @click="isOpen = !isOpen"
      >
        <span class="i-ri-phone-fill size-6" />
        <span
          class="absolute right-0 top-0 size-3 rounded-full border-2 border-n-solid-2"
          :class="registered ? 'bg-n-teal-9' : 'bg-n-ruby-9'"
        />
      </button>

      <audio ref="remoteAudio" autoplay playsinline />
    </div>
  </div>
</template>
