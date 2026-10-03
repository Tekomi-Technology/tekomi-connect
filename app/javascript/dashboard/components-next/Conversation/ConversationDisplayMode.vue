<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: {
    type: String,
    default: wootConstants.DISPLAY_MODE.DEFAULT,
  },
  options: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const isMenuOpen = ref(false);

const isDefault = computed(
  () => props.modelValue === wootConstants.DISPLAY_MODE.DEFAULT
);

const selectMode = value => {
  isMenuOpen.value = false;
  if (value !== props.modelValue) emit('update:modelValue', value);
};
</script>

<template>
  <div class="relative flex-shrink-0">
    <Button
      :label="t('CHAT_LIST.DISPLAY_MODE.LABEL')"
      icon="i-lucide-settings-2"
      slate
      xs
      faded
      class="max-w-40"
      :class="{ '!text-n-blue-text !bg-n-blue-3': !isDefault }"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute z-30 flex flex-col p-1 mt-1 border shadow-lg top-full w-72 rounded-xl border-n-weak bg-n-solid-2 ltr:right-0 rtl:left-0"
    >
      <span
        class="px-2 py-1.5 text-xs font-medium uppercase text-n-slate-10 tracking-wide"
      >
        {{ t('CHAT_LIST.DISPLAY_MODE.LABEL') }}
      </span>
      <button
        v-for="option in options"
        :key="option.value"
        type="button"
        class="flex items-center gap-2.5 px-2 py-2 text-sm rounded-lg text-start hover:bg-n-alpha-1"
        :class="
          option.value === modelValue
            ? 'bg-n-alpha-2 text-n-blue-text font-medium'
            : 'text-n-slate-12'
        "
        @click="selectMode(option.value)"
      >
        <Icon
          :icon="
            option.value === modelValue
              ? 'i-lucide-circle-dot'
              : 'i-lucide-circle'
          "
          class="flex-shrink-0 size-4"
        />
        {{ option.label }}
      </button>
    </div>
  </div>
</template>
