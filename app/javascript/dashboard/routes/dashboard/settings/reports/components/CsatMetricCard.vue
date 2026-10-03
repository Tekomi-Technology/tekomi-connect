<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  tooltip: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div
    class="flex flex-col items-start gap-2 p-4 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
  >
    <span
      class="inline-flex items-center gap-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
    >
      {{ label }}
      <span
        v-tooltip.right="tooltip"
        class="i-lucide-info flex flex-shrink-0 text-n-slate-10 size-3.5"
      />
    </span>
    <div
      v-if="isLoading"
      class="w-16 h-9 rounded-md bg-n-slate-3 animate-pulse"
    />
    <span
      v-else
      class="text-3xl font-semibold tracking-tight text-n-slate-12"
    >
      {{ value }}
    </span>
  </div>
</template>
