<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  to: { type: [Object, String], default: '' },
  label: { type: String, default: '' },
  icon: { type: [String, Object], default: '' },
  iconColor: { type: String, default: '' },
  expandable: { type: Boolean, default: false },
  isExpanded: { type: Boolean, default: false },
  isActive: { type: Boolean, default: false },
  hasActiveChild: { type: Boolean, default: false },
  getterKeys: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['toggle']);

const showBadge = useMapGetter(props.getterKeys.badge);
const dynamicCount = useMapGetter(props.getterKeys.count);
const count = computed(() =>
  dynamicCount.value > 99 ? '99+' : dynamicCount.value
);

const isHighlighted = computed(() => props.isActive && !props.hasActiveChild);

const iconClass = computed(() => {
  if (isHighlighted.value) return 'text-white';
  if (props.hasActiveChild) return 'text-n-teal-11';
  return props.iconColor;
});
</script>

<template>
  <component
    :is="to ? 'router-link' : 'div'"
    class="relative flex items-center gap-3 ps-3.5 pe-3 rounded-[10px] h-[42px] min-w-0 text-[13.5px] transition-[background-color,color,box-shadow] duration-150"
    role="button"
    draggable="false"
    :to="to"
    :title="label"
    :class="{
      'text-white font-semibold bg-gradient-to-r from-[#0e7490] to-[#0891b2] shadow-[0_8px_18px_-8px_rgba(6,182,212,0.65),inset_0_1px_0_rgba(255,255,255,0.14)]':
        isHighlighted,
      'text-white font-semibold': hasActiveChild,
      'text-n-slate-12 font-medium hover:bg-white/[0.08] hover:text-white':
        !isActive && !hasActiveChild,
    }"
    @click.stop="emit('toggle')"
  >
    <div v-if="icon" class="relative flex items-center gap-2">
      <Icon v-if="icon" :icon="icon" class="size-4" :class="iconClass" />
      <span
        v-if="showBadge"
        class="size-2 -top-px ltr:-right-px rtl:-left-px bg-n-brand absolute rounded-full border border-n-solid-2"
      />
    </div>
    <div
      class="flex items-center gap-1.5 flex-grow justify-between min-w-0 flex-1"
    >
      <span class="truncate">
        {{ label }}
      </span>
      <span
        v-if="dynamicCount && !expandable"
        class="inline-grid h-[18px] min-w-5 place-items-center rounded-full px-1.5 text-[10.5px] font-bold leading-3 flex-shrink-0"
        :class="
          isHighlighted ? 'bg-white text-[#0e7490]' : 'bg-[#0e7490] text-white'
        "
      >
        {{ count }}
      </span>
    </div>
    <span
      v-if="expandable"
      v-show="isExpanded"
      class="i-lucide-chevron-up size-3"
      @click.stop="emit('toggle')"
    />
  </component>
</template>
