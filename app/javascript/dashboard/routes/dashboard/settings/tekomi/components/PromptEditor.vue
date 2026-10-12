<script setup>
import { computed, ref } from 'vue';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const gutterRef = ref(null);

const lineNumbers = computed(() =>
  Array.from({ length: props.modelValue.split('\n').length }, (_, i) => i + 1)
);

// The gutter is a separate scroll container, so it has to follow the textarea.
const onScroll = event => {
  if (gutterRef.value) gutterRef.value.scrollTop = event.target.scrollTop;
};
</script>

<template>
  <div
    class="flex overflow-hidden border rounded-lg border-n-weak bg-n-alpha-black1"
  >
    <div
      ref="gutterRef"
      aria-hidden="true"
      class="py-3 overflow-hidden text-right border-r select-none shrink-0 w-11 border-n-weak bg-n-alpha-1"
    >
      <div
        v-for="number in lineNumbers"
        :key="number"
        class="pr-2 font-mono text-xs leading-5 text-n-slate-9"
      >
        {{ number }}
      </div>
    </div>
    <textarea
      :value="modelValue"
      spellcheck="false"
      wrap="off"
      class="flex-grow min-w-0 px-3 py-3 font-mono text-xs leading-5 bg-transparent border-0 resize-none text-n-slate-12 h-[27rem] focus:outline-none focus:ring-0"
      @scroll="onScroll"
      @input="emit('update:modelValue', $event.target.value)"
    />
  </div>
</template>
