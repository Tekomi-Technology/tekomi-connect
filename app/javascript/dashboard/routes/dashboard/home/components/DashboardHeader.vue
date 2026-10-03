<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useNow } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import { PERIODS } from '../helpers';

defineProps({
  updatedAt: { type: Number, default: null },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['refresh']);

const period = defineModel('period', { type: String, required: true });
const inboxId = defineModel('inboxId', { type: String, required: true });

const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const inboxes = useMapGetter('inboxes/getInboxes');
const now = useNow({ interval: 30000 });

const inboxOptions = computed(() => [
  { value: '', label: t('HOME.DASHBOARD.FILTER.ALL_CHANNELS') },
  ...inboxes.value.map(inbox => ({
    value: String(inbox.id),
    label: inbox.name,
  })),
]);

const inboxLabel = computed(() =>
  t('HOME.DASHBOARD.FILTER.CHANNEL', {
    name: inboxOptions.value.find(option => option.value === inboxId.value)
      ?.label,
  })
);

const updatedLabel = (updatedAt, current) => {
  if (!updatedAt) return t('HOME.DASHBOARD.UPDATING');
  const minutes = Math.floor((current - updatedAt) / 60000);
  return minutes < 1
    ? t('HOME.DASHBOARD.UPDATED_NOW')
    : t('HOME.DASHBOARD.UPDATED_AGO', { minutes });
};
</script>

<template>
  <header
    class="flex flex-col gap-4 p-6 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
  >
    <div class="flex flex-col gap-1">
      <div class="flex items-center gap-2">
        <h1 class="text-2xl font-semibold tracking-tight text-n-slate-12">
          {{ t('HOME.TITLE') }}
        </h1>
        <span
          class="flex items-center gap-1 px-2 py-0.5 rounded-full bg-n-brand/10 text-n-brand text-[11px] font-semibold uppercase tracking-wide"
        >
          <span class="rounded-full size-1.5 bg-n-brand animate-pulse" />
          {{ t('HOME.DASHBOARD.LIVE') }}
        </span>
      </div>
      <p class="flex flex-wrap gap-x-1.5 text-sm text-n-slate-11">
        <span class="font-medium text-n-slate-12">
          {{ t('HOME.GREETING', { name: currentUser.name }) }}
        </span>
        <span>{{ t('HOME.DASHBOARD.TAGLINE') }}</span>
      </p>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <div
        class="flex items-center gap-1 p-1 border rounded-xl bg-n-alpha-1 border-n-weak"
      >
        <button
          v-for="option in PERIODS"
          :key="option"
          type="button"
          class="px-3 py-1 rounded-lg text-[13px] font-medium transition-all duration-200"
          :class="
            period === option
              ? 'bg-white shadow-sm text-n-brand dark:bg-n-solid-3'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="period = option"
        >
          {{ t(`HOME.DASHBOARD.PERIOD.${option.toUpperCase()}`) }}
        </button>
      </div>
      <SelectMenu
        v-model="inboxId"
        :options="inboxOptions"
        :label="inboxLabel"
        sub-menu-position="bottom"
      />
      <button
        type="button"
        class="flex items-center gap-2 px-3 py-1.5 rounded-xl border border-n-weak text-[13px] text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-1"
        :disabled="isLoading"
        @click="emit('refresh')"
      >
        <span class="rounded-full size-2 bg-n-teal-9" />
        {{ updatedLabel(updatedAt, now.getTime()) }}
        <span
          class="i-lucide-refresh-cw size-3.5"
          :class="{ 'animate-spin': isLoading }"
        />
      </button>
    </div>
  </header>
</template>
