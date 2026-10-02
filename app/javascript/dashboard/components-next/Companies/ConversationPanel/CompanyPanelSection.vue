<script setup>
defineProps({
  title: { type: String, required: true },
  isOpen: { type: Boolean, default: true },
});

const emit = defineEmits(['toggle']);
</script>

<template>
  <section class="flex flex-col gap-2">
    <div class="flex items-center justify-between gap-2">
      <button
        type="button"
        class="flex items-center flex-1 min-w-0 gap-1.5 text-left"
        :aria-expanded="isOpen"
        @click="emit('toggle')"
      >
        <h4 class="m-0 text-xs font-semibold truncate text-n-slate-12">
          {{ title }}
        </h4>
        <span
          class="flex-shrink-0 text-[10px] i-lucide-chevron-down text-n-slate-10 transition-transform duration-200"
          :class="{ 'rotate-180': isOpen }"
        />
      </button>
      <slot name="action" />
    </div>
    <div v-show="isOpen">
      <slot />
    </div>
  </section>
</template>
