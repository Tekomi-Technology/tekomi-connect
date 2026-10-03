<script setup>
import Spinner from 'shared/components/Spinner.vue';

defineProps({
  header: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  showLiveBadge: {
    type: Boolean,
    default: true,
  },
  bodyClass: {
    type: String,
    default: 'flex justify-between w-full max-w-full',
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <section
    class="flex flex-col flex-grow min-w-0 gap-4 p-5 transition-shadow duration-300 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2 hover:shadow-md"
  >
    <header class="flex items-start justify-between w-full gap-3">
      <slot name="header">
        <div class="flex items-start min-w-0 gap-3">
          <span
            v-if="icon"
            class="flex items-center justify-center rounded-xl size-9 shrink-0 bg-n-brand/10 text-n-brand"
          >
            <span class="size-5" :class="icon" />
          </span>
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h3
                class="text-base font-semibold tracking-tight text-n-slate-12"
              >
                {{ header }}
              </h3>
              <span
                v-if="showLiveBadge"
                class="flex items-center gap-1 px-2 py-0.5 rounded-full bg-n-brand/10 text-n-brand text-[11px] font-semibold uppercase tracking-wide"
              >
                <span class="rounded-full size-1.5 bg-n-brand animate-pulse" />
                {{ $t('OVERVIEW_REPORTS.LIVE') }}
              </span>
            </div>
            <p v-if="description" class="text-[13px] text-n-slate-11">
              {{ description }}
            </p>
          </div>
        </div>
        <div class="flex flex-row items-center justify-end flex-shrink-0 gap-2">
          <slot name="control" />
        </div>
      </slot>
    </header>
    <div v-if="!isLoading" :class="bodyClass">
      <slot />
    </div>
    <div
      v-else
      class="flex items-center justify-center px-12 py-6 text-base gap-2"
    >
      <Spinner />
      <span class="text-n-slate-11">
        {{ loadingMessage }}
      </span>
    </div>
  </section>
</template>
