<script>
export default {
  props: {
    label: {
      type: String,
      required: true,
    },
    value: {
      type: [String, Number],
      required: true,
    },
    toolTip: {
      type: String,
      required: true,
    },
    isLoading: {
      type: Boolean,
      default: false,
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col items-start gap-2 p-4 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
  >
    <span
      class="inline-flex items-center gap-1 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
    >
      {{ label }}
      <fluent-icon
        v-tooltip.right="toolTip"
        size="14"
        icon="information"
        type="outline"
        class="flex flex-shrink-0 text-sm font-normal sm:font-medium text-n-slate-10"
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
