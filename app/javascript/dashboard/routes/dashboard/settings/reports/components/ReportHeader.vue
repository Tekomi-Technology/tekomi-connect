<script setup>
import { useSlots } from 'vue';
import BackButton from 'dashboard/components/widgets/BackButton.vue';

defineProps({
  headerTitle: {
    required: true,
    type: String,
  },
  headerDescription: {
    type: String,
    default: '',
  },
  hasBackButton: {
    type: Boolean,
    default: false,
  },
  isLive: {
    type: Boolean,
    default: false,
  },
});

const slots = useSlots();
</script>

<template>
  <header
    class="flex flex-col gap-4 p-6 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
  >
    <div v-if="hasBackButton">
      <BackButton compact />
    </div>
    <div class="flex items-start justify-between w-full gap-5">
      <div class="flex flex-col min-w-0 gap-1">
        <div class="flex items-center gap-2">
          <h1 class="text-2xl font-semibold tracking-tight text-n-slate-12">
            {{ headerTitle }}
          </h1>
          <span
            v-if="isLive"
            class="flex items-center gap-1 px-2 py-0.5 rounded-full bg-n-brand/10 text-n-brand text-[11px] font-semibold uppercase tracking-wide"
          >
            <span class="rounded-full size-1.5 bg-n-brand animate-pulse" />
            {{ $t('OVERVIEW_REPORTS.LIVE') }}
          </span>
        </div>
        <p
          v-if="headerDescription"
          class="mb-0 text-sm text-n-slate-11 line-clamp-5 sm:line-clamp-none"
        >
          {{ headerDescription }}
        </p>
      </div>
      <div class="flex-shrink-0">
        <slot />
      </div>
    </div>
    <div v-if="slots.filters" class="flex flex-wrap items-center gap-2">
      <slot name="filters" />
    </div>
  </header>
</template>
