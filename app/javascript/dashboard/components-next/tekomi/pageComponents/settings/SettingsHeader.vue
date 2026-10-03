<script setup>
defineProps({
  heading: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <header class="flex flex-col items-start gap-2">
    <h2 class="text-base font-semibold tracking-tight text-n-slate-12">
      {{ heading }}
    </h2>
    <p class="text-[13px] text-n-slate-11">{{ description }}</p>
  </header>
</template>
