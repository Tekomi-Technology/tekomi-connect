<script setup>
import { computed } from 'vue';

const props = defineProps({
  text: { type: String, required: true },
});

// Longest marker first so «**» is not read as «*».
const MARKERS = [
  { token: '**', kind: 'bold' },
  { token: '*', kind: 'italic' },
  { token: '`', kind: 'code' },
];

const segments = computed(() =>
  props.text
    .split(/(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/)
    .filter(Boolean)
    .map(part => {
      const marker = MARKERS.find(({ token }) => part.startsWith(token));
      if (!marker) {
        return { kind: 'plain', text: part };
      }
      const size = marker.token.length;
      return { kind: marker.kind, text: part.slice(size, -size) };
    })
);
</script>

<template>
  <template v-for="(segment, index) in segments" :key="index">
    <strong
      v-if="segment.kind === 'bold'"
      class="font-semibold text-n-slate-12"
    >
      {{ segment.text }}
    </strong>
    <em v-else-if="segment.kind === 'italic'">{{ segment.text }}</em>
    <code
      v-else-if="segment.kind === 'code'"
      class="px-1 py-0.5 text-xs rounded bg-n-alpha-2 text-n-slate-12"
    >
      {{ segment.text }}
    </code>
    <template v-else>{{ segment.text }}</template>
  </template>
</template>
