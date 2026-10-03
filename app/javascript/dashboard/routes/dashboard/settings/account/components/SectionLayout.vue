<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  title: { type: String, required: true },
  description: { type: String, required: true },
  hideContent: { type: Boolean, default: false },
  beta: { type: Boolean, default: false },
});
const { t } = useI18n();
</script>

<template>
  <section
    class="grid grid-cols-1 p-6 bg-white border shadow-sm rounded-2xl border-n-weak dark:bg-n-solid-2 [interpolate-size:allow-keywords]"
    :class="{ 'gap-5': !hideContent }"
  >
    <header class="grid grid-cols-4">
      <div
        v-if="
          title || beta || $slots.title || description || $slots.description
        "
        class="col-span-3"
      >
        <h4
          v-if="title || beta || $slots.title"
          class="flex items-center gap-2 text-base font-semibold tracking-tight text-n-slate-12"
        >
          <slot name="title">{{ title }}</slot>
          <div
            v-if="beta"
            v-tooltip.top="t('GENERAL.BETA_DESCRIPTION')"
            class="text-xs uppercase text-n-iris-11 border border-1 border-n-iris-10 leading-none rounded-lg px-1 py-0.5"
          >
            {{ t('GENERAL.BETA') }}
          </div>
        </h4>
        <p
          v-if="description || $slots.description"
          class="mt-1 text-[13px] text-n-slate-11"
        >
          <slot name="description">{{ description }}</slot>
        </p>
      </div>
      <div class="col-span-1">
        <slot name="headerActions" />
      </div>
    </header>
    <div
      class="transition-[height] duration-300 ease-in-out text-n-slate-12"
      :class="{ 'overflow-hidden h-0': hideContent, 'h-auto': !hideContent }"
    >
      <slot />
    </div>
  </section>
</template>
