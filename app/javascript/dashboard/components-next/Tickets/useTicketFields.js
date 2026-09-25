import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { customAttributeKey } from './constants';

export function useTicketFields() {
  const { t } = useI18n();
  const ticketAttributes = useMapGetter('attributes/getTicketAttributes');

  const attributesByKey = computed(() =>
    Object.fromEntries(
      ticketAttributes.value.map(attribute => [
        attribute.attributeKey,
        attribute,
      ])
    )
  );

  const findAttribute = field =>
    attributesByKey.value[customAttributeKey(field)];

  const fieldLabel = field =>
    customAttributeKey(field)
      ? findAttribute(field)?.attributeDisplayName
      : t(`TICKETS.FIELDS.${field.toUpperCase()}`);

  return { ticketAttributes, findAttribute, fieldLabel };
}
