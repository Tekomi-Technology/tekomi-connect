<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  value: {
    type: String,
    required: true,
  },
  infoText: {
    type: String,
    required: true,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div
    data-test-id="reportMetricContainer"
    class="flex flex-col gap-2 p-4 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2"
    :class="{
      'grayscale pointer-events-none opacity-30': disabled,
    }"
  >
    <h3
      class="flex items-center m-0 text-[11px] font-semibold tracking-wide uppercase text-n-slate-11"
    >
      <span data-test-id="reportMetricLabel">{{ label }}</span>
      <fluent-icon
        v-tooltip="infoText"
        data-test-id="reportMetricInfo"
        size="14"
        icon="info"
        class="text-n-slate-10 my-0 mx-1"
      />
    </h3>
    <h4
      data-test-id="reportMetricValue"
      class="m-0 text-3xl font-semibold tracking-tight text-n-slate-12"
    >
      {{ value }}
    </h4>
  </div>
</template>
