<script setup>
import { computed } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.ASSIGNEE_TYPE.ME,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex >= 0 && selectedTabIndex < props.items.length) {
    const selectedItem = props.items[selectedTabIndex];
    if (selectedItem.key !== props.activeTab) {
      emit('chatTabChange', selectedItem.key);
    }
  }
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (props.activeTab === wootConstants.ASSIGNEE_TYPE.ALL) {
        onTabChange(0);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(nextIndex);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <div role="tablist" class="flex items-center w-full gap-1 px-3 py-2">
    <button
      v-for="(item, index) in items"
      :key="item.key"
      type="button"
      role="tab"
      :aria-selected="index === activeTabIndex"
      class="flex items-center gap-1.5 h-7 px-2.5 rounded-lg text-[13px] whitespace-nowrap transition-colors"
      :class="
        index === activeTabIndex
          ? 'bg-n-teal-3 text-n-teal-11 font-bold'
          : 'text-n-slate-11 font-semibold hover:bg-n-alpha-2'
      "
      @click="onTabChange(index)"
    >
      {{ item.name }}
      <span
        v-if="item.count"
        class="inline-grid h-[18px] min-w-[18px] px-1 place-items-center rounded-full text-[11px] font-semibold"
        :class="
          index === activeTabIndex
            ? 'bg-n-teal-9 text-white'
            : 'bg-n-alpha-2 text-n-slate-11'
        "
      >
        {{ item.count > 99 ? '99+' : item.count }}
      </span>
    </button>
  </div>
</template>
