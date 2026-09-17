<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useDealsStore } from 'dashboard/stores/deals';
import ListAttribute from 'dashboard/components-next/CustomAttributes/ListAttribute.vue';
import CheckboxAttribute from 'dashboard/components-next/CustomAttributes/CheckboxAttribute.vue';
import DateAttribute from 'dashboard/components-next/CustomAttributes/DateAttribute.vue';
import OtherAttribute from 'dashboard/components-next/CustomAttributes/OtherAttribute.vue';
import { useDealFields } from '../useDealFields';

const props = defineProps({
  deal: { type: Object, required: true },
});

const emit = defineEmits(['updated']);

const COMPONENTS = {
  list: ListAttribute,
  checkbox: CheckboxAttribute,
  date: DateAttribute,
};

const { t } = useI18n();
const dealsStore = useDealsStore();
const { dealAttributes } = useDealFields();

const attributes = computed(() =>
  dealAttributes.value.map(attribute => ({
    ...attribute,
    value: props.deal.customAttributes?.[attribute.attributeKey] ?? '',
  }))
);

const saveCustomAttributes = async customAttributes => {
  try {
    emit('updated', await dealsStore.update(props.deal, { customAttributes }));
  } catch {
    useAlert(t('DEALS.MESSAGES.UPDATE_ERROR'));
  }
};

const updateAttribute = (attribute, value) => {
  saveCustomAttributes({
    ...props.deal.customAttributes,
    [attribute.attributeKey]: value,
  });
};

const removeAttribute = attribute => {
  const { [attribute.attributeKey]: _removed, ...rest } =
    props.deal.customAttributes || {};
  saveCustomAttributes(rest);
};
</script>

<template>
  <div v-if="attributes.length" class="flex flex-col gap-1">
    <h4 class="mb-1 text-sm font-medium text-n-slate-12">
      {{ t('DEALS.DETAIL.CUSTOM_ATTRIBUTES') }}
    </h4>
    <div
      v-for="attribute in attributes"
      :key="attribute.id"
      class="grid grid-cols-[9rem_1fr] items-center gap-4 min-h-10 group/attribute"
    >
      <span class="text-sm truncate text-n-slate-11">
        {{ attribute.attributeDisplayName }}
      </span>
      <component
        :is="COMPONENTS[attribute.attributeDisplayType] || OtherAttribute"
        :attribute="attribute"
        is-editing-view
        @update="updateAttribute(attribute, $event)"
        @delete="removeAttribute(attribute)"
      />
    </div>
  </div>
</template>
