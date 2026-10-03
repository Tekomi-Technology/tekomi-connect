<script setup>
defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
  noRecordsFound: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: '',
  },
  noRecordsMessage: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="flex flex-col w-full h-full gap-5 font-inter">
    <slot name="header" />
    <!-- Added to render any templates that should be rendered before body -->
    <!-- A table placed straight in the body sits in a Home-style card. BaseTable is
         shared outside settings, so the card is applied here instead of in BaseTable. -->
    <main
      class="[&>div:has(>table)]:px-5 [&>div:has(>table)]:bg-white dark:[&>div:has(>table)]:bg-n-solid-2 [&>div:has(>table)]:border [&>div:has(>table)]:border-n-weak [&>div:has(>table)]:rounded-2xl [&>div:has(>table)]:shadow-sm [&>div>table>thead]:border-t-0"
    >
      <slot name="preBody" />
      <slot v-if="isLoading" name="loading">
        <woot-loading-state :message="loadingMessage" />
      </slot>
      <p
        v-else-if="noRecordsFound"
        class="flex-1 py-20 text-n-slate-12 flex items-center justify-center text-base"
      >
        {{ noRecordsMessage }}
      </p>
      <slot v-else name="body" />
      <!-- Do not delete the slot below. It is required to render anything that is not defined in the above slots. -->
      <slot />
    </main>
  </div>
</template>
