import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { customAttributeKey } from './constants';

export function useDealFields() {
  const { t } = useI18n();
  const dealAttributes = useMapGetter('attributes/getDealAttributes');

  const attributesByKey = computed(() =>
    Object.fromEntries(
      dealAttributes.value.map(attribute => [attribute.attributeKey, attribute])
    )
  );

  const findAttribute = field => attributesByKey.value[customAttributeKey(field)];

  const fieldLabel = field =>
    customAttributeKey(field)
      ? findAttribute(field)?.attributeDisplayName
      : t(`DEALS.FIELDS.${field.toUpperCase()}`);

  return { dealAttributes, findAttribute, fieldLabel };
}
