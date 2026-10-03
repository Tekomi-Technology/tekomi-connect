<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { VIEW_TYPES, normalizeFields } from './constants';
import { useTicketFields } from './useTicketFields';

const props = defineProps({
  view: { type: Object, required: true },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const { ticketAttributes, fieldLabel } = useTicketFields();
const isMenuOpen = ref(false);

const fields = computed(() =>
  normalizeFields(props.view, ticketAttributes.value)
);
const settings = computed(() => props.view.settings || {});

const updateFields = nextFields => emit('update', { fields: nextFields });

const toggleField = (key, visible) => {
  updateFields(
    fields.value.map(field =>
      field.key === key ? { ...field, visible } : field
    )
  );
};

const updateSetting = (key, value) => {
  emit('update', { settings: { ...settings.value, [key]: value } });
};
</script>

<template>
  <div class="relative">
    <Button
      :label="t('TICKETS.TOOLBAR.OPTIONS')"
      icon="i-lucide-sliders-horizontal"
      color="slate"
      size="sm"
      variant="ghost"
      :class="{ 'bg-n-alpha-2': isMenuOpen }"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-click-outside="() => (isMenuOpen = false)"
      class="absolute z-40 flex flex-col gap-4 p-4 mt-1 border top-full ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] border-n-weak w-72 rounded-xl"
    >
      <label
        v-if="view.viewType === VIEW_TYPES.KANBAN"
        class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
      >
        <Checkbox
          :model-value="!!settings.hide_empty_columns"
          @update:model-value="updateSetting('hide_empty_columns', $event)"
        />
        {{ t('TICKETS.OPTIONS.HIDE_EMPTY_COLUMNS') }}
      </label>

      <div class="flex flex-col gap-2">
        <span class="text-xs font-medium uppercase text-n-slate-11">
          {{ t('TICKETS.OPTIONS.VISIBLE_FIELDS') }}
        </span>
        <Draggable
          :model-value="fields"
          item-key="key"
          handle=".field-handle"
          ghost-class="opacity-40"
          animation="150"
          class="flex flex-col gap-1"
          @update:model-value="updateFields"
        >
          <template #item="{ element }">
            <div class="flex items-center gap-2 py-1 text-sm text-n-slate-12">
              <Icon
                icon="i-lucide-grip-vertical"
                class="field-handle size-4 cursor-grab text-n-slate-10"
              />
              <Checkbox
                :model-value="element.visible"
                @update:model-value="toggleField(element.key, $event)"
              />
              {{ fieldLabel(element.key) }}
            </div>
          </template>
        </Draggable>
      </div>
    </div>
  </div>
</template>
