<script setup>
defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: '—' },
  unit: { type: String, default: '' },
  hint: { type: String, default: '' },
  tone: { type: String, default: 'slate' },
});

const VALUE_TONES = {
  slate: 'text-n-slate-12',
  brand: 'text-n-brand',
  amber: 'text-n-amber-11',
  ruby: 'text-n-ruby-11',
  violet: 'text-n-violet-11',
};
</script>

<template>
  <div
    class="flex flex-col gap-1 p-3 border rounded-xl border-n-weak bg-n-alpha-1"
  >
    <span class="text-[11px] font-medium text-n-slate-11">
      <slot name="label">{{ label }}</slot>
    </span>
    <span class="flex items-baseline gap-1">
      <span
        class="text-2xl font-semibold tracking-tight"
        :class="VALUE_TONES[tone]"
      >
        {{ value }}
      </span>
      <span v-if="unit" class="text-xs font-medium text-n-slate-11">
        {{ unit }}
      </span>
    </span>
    <span v-if="hint" class="text-[11px] text-n-slate-11">{{ hint }}</span>
  </div>
</template>
