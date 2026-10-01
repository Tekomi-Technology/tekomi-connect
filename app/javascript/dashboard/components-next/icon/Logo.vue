<script setup>
import { computed, useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  // The sidebar is always rendered dark regardless of the app theme, so it opts
  // in explicitly rather than relying on a prefers-color-scheme style switch.
  dark: {
    type: Boolean,
    default: false,
  },
  // `thumbnail` is the square mark (favicon-style), used in tight square slots
  // like the collapsed sidebar. `full` is the wide wordmark used where there is
  // room to show the brand name as part of the logo (e.g. the expanded sidebar).
  variant: {
    type: String,
    default: 'thumbnail',
    validator: value => ['thumbnail', 'full'].includes(value),
  },
});

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');

const source = computed(() => {
  if (props.variant === 'full') {
    // No dark-specific wordmark exists, so the standard logo is used for both
    // themes; it reads fine on the dark sidebar.
    return globalConfig.value.logo || globalConfig.value.logoThumbnail;
  }

  return props.dark
    ? globalConfig.value.logoDark || globalConfig.value.logoThumbnail
    : globalConfig.value.logoThumbnail;
});
</script>

<template>
  <img v-if="source" v-bind="attrs" :src="source" />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <g clip-path="url(#woot-logo-clip-2342424e23u32098)">
      <path
        d="M8 16C12.4183 16 16 12.4183 16 8C16 3.58172 12.4183 0 8 0C3.58172 0 0 3.58172 0 8C0 12.4183 3.58172 16 8 16Z"
        fill="#2781F6"
      />
      <path
        d="M11.4172 11.4172H7.70831C5.66383 11.4172 4 9.75328 4 7.70828C4 5.66394 5.66383 4 7.70835 4C9.75339 4 11.4172 5.66394 11.4172 7.70828V11.4172Z"
        fill="white"
        stroke="white"
        stroke-width="0.1875"
      />
    </g>
    <defs>
      <clipPath id="woot-logo-clip-2342424e23u32098">
        <rect width="16" height="16" fill="white" />
      </clipPath>
    </defs>
  </svg>
</template>
