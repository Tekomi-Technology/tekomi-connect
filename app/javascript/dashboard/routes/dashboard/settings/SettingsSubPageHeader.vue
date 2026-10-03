<script>
export default {
  props: {
    headerTitle: { type: String, default: '' },
    headerContent: { type: String, default: '' },
  },
};
</script>

<template>
  <div class="flex flex-col gap-1.5 w-full items-start mb-4">
    <h2 class="text-2xl font-semibold tracking-tight break-words text-n-slate-12">
      {{ headerTitle }}
    </h2>
    <p v-dompurify-html="headerContent" class="w-full text-sm text-n-slate-11" />
  </div>
</template>
