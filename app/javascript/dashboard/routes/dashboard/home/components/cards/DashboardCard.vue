<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
});
</script>

<template>
  <section
    class="flex flex-col min-w-0 gap-4 p-5 transition-shadow duration-300 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2 hover:shadow-md"
  >
    <header v-if="title" class="flex items-start justify-between gap-3">
      <div class="flex items-start min-w-0 gap-3">
        <span
          v-if="icon"
          class="flex items-center justify-center rounded-xl size-9 shrink-0 bg-n-brand/10 text-n-brand"
        >
          <span class="size-5" :class="icon" />
        </span>
        <div class="min-w-0">
          <h3 class="text-base font-semibold tracking-tight text-n-slate-12">
            {{ title }}
          </h3>
          <p v-if="subtitle" class="text-[13px] text-n-slate-11">
            {{ subtitle }}
          </p>
        </div>
      </div>
      <slot name="action" />
    </header>
    <slot />
  </section>
</template>
