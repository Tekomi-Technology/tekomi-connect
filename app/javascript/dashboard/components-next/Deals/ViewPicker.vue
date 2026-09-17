<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { VIEW_TYPE_ICONS } from './constants';

const props = defineProps({
  views: { type: Array, required: true },
  activeView: { type: Object, default: null },
  count: { type: Number, default: 0 },
});

const emit = defineEmits(['select', 'create', 'rename', 'duplicate', 'delete']);

const { t } = useI18n();
const isViewMenuOpen = ref(false);
const isActionMenuOpen = ref(false);

const viewMenuSections = computed(() => [
  {
    items: props.views.map(view => ({
      label: view.name,
      value: view.id,
      action: 'select',
      icon: VIEW_TYPE_ICONS[view.viewType],
      isSelected: view.id === props.activeView?.id,
    })),
  },
  {
    items: [
      {
        label: t('DEALS.VIEWS.CREATE'),
        value: 'create',
        action: 'create',
        icon: 'i-lucide-plus',
      },
    ],
  },
]);

const actionMenuItems = computed(() => [
  {
    label: t('DEALS.VIEWS.RENAME'),
    value: 'rename',
    action: 'rename',
    icon: 'i-lucide-pencil',
  },
  {
    label: t('DEALS.VIEWS.DUPLICATE'),
    value: 'duplicate',
    action: 'duplicate',
    icon: 'i-lucide-copy',
  },
  {
    label: t('DEALS.VIEWS.DELETE'),
    value: 'delete',
    action: 'delete',
    icon: 'i-lucide-trash',
    disabled: props.views.length <= 1,
  },
]);

const handleViewMenuAction = ({ action, value }) => {
  isViewMenuOpen.value = false;
  if (action === 'select') emit('select', value);
  else emit('create');
};

const handleActionMenuAction = ({ action }) => {
  isActionMenuOpen.value = false;
  emit(action, props.activeView);
};
</script>

<template>
  <div class="flex items-center gap-1 min-w-0">
    <div
      v-on-clickaway="() => (isViewMenuOpen = false)"
      class="relative min-w-0"
    >
      <button
        type="button"
        class="flex items-center min-w-0 gap-2 px-2 py-1 text-sm rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
        :class="{ 'bg-n-alpha-2': isViewMenuOpen }"
        @click="isViewMenuOpen = !isViewMenuOpen"
      >
        <Icon
          v-if="activeView"
          :icon="VIEW_TYPE_ICONS[activeView.viewType]"
          class="flex-shrink-0 size-4 text-n-slate-11"
        />
        <span class="font-medium truncate">{{ activeView?.name }}</span>
        <span class="flex-shrink-0 text-n-slate-11">
          {{ t('DEALS.COUNT', count) }}
        </span>
        <Icon
          icon="i-lucide-chevron-down"
          class="flex-shrink-0 size-4 text-n-slate-11"
        />
      </button>
      <DropdownMenu
        v-if="isViewMenuOpen"
        :menu-sections="viewMenuSections"
        class="mt-1 w-64 top-full ltr:left-0 rtl:right-0 max-h-96"
        @action="handleViewMenuAction"
      />
    </div>
    <div
      v-if="activeView"
      v-on-clickaway="() => (isActionMenuOpen = false)"
      class="relative"
    >
      <Button
        icon="i-lucide-ellipsis"
        color="slate"
        variant="ghost"
        size="sm"
        :class="{ 'bg-n-alpha-2': isActionMenuOpen }"
        @click="isActionMenuOpen = !isActionMenuOpen"
      />
      <DropdownMenu
        v-if="isActionMenuOpen"
        :menu-items="actionMenuItems"
        class="mt-1 w-52 top-full ltr:left-0 rtl:right-0"
        @action="handleActionMenuAction"
      />
    </div>
  </div>
</template>
