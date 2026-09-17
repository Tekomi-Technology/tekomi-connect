<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { VIEW_TYPES, VIEW_TYPE_ICONS } from './constants';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const { t } = useI18n();
const dialogRef = ref(null);
const isRename = ref(false);
const name = ref('');
const viewType = ref(VIEW_TYPES.KANBAN);

const viewTypeOptions = Object.values(VIEW_TYPES);

const title = computed(() =>
  isRename.value
    ? t('DEALS.VIEWS.DIALOG.RENAME_TITLE')
    : t('DEALS.VIEWS.DIALOG.CREATE_TITLE')
);

const open = (view = null) => {
  isRename.value = !!view;
  name.value = view?.name || '';
  viewType.value = view?.viewType || VIEW_TYPES.KANBAN;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const handleConfirm = () => {
  if (!name.value.trim()) return;
  emit('save', { name: name.value.trim(), viewType: viewType.value });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="title"
    :confirm-button-label="t('DEALS.VIEWS.DIALOG.SAVE')"
    :disable-confirm-button="!name.trim()"
    :is-loading="isLoading"
    @confirm="handleConfirm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="name"
        :placeholder="t('DEALS.VIEWS.DIALOG.NAME_PLACEHOLDER')"
        autofocus
      />
      <div v-if="!isRename" class="flex flex-col gap-2">
        <span class="text-sm text-n-slate-11">
          {{ t('DEALS.VIEWS.DIALOG.TYPE_LABEL') }}
        </span>
        <div class="grid grid-cols-2 gap-2">
          <button
            v-for="type in viewTypeOptions"
            :key="type"
            type="button"
            class="flex items-center gap-2 px-3 py-2 text-sm rounded-lg outline outline-1 -outline-offset-1 text-n-slate-12"
            :class="
              viewType === type
                ? 'outline-n-brand bg-n-alpha-2'
                : 'outline-n-weak hover:bg-n-alpha-1'
            "
            @click="viewType = type"
          >
            <Icon :icon="VIEW_TYPE_ICONS[type]" class="size-4" />
            {{ t(`DEALS.VIEW_TYPES.${type.toUpperCase()}`) }}
          </button>
        </div>
      </div>
    </div>
  </Dialog>
</template>
