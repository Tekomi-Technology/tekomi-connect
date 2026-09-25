<script setup>
defineProps({
  items: {
    type: Array,
    required: true,
  },
});
</script>

<template>
  <div
    v-for="item in items"
    :key="item.key"
    class="flex flex-col gap-0.5"
  >
    <span class="text-xs text-n-slate-11">{{ item.label }}</span>
    <span class="text-sm text-n-slate-12">{{ item.value }}</span>
  </div>
</template>
