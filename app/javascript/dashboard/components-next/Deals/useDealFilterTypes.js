import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useOperators } from 'dashboard/components-next/filter/operators';
import { buildAttributesFilterTypes } from 'dashboard/components-next/filter/helper/filterHelper';

export function useDealFilterTypes(stages) {
  const { t } = useI18n();
  const agents = useMapGetter('agents/getAgents');
  const dealAttributes = useMapGetter('attributes/getDealAttributes');
  const {
    operators,
    equalityOperators,
    presenceOperators,
    containmentOperators,
    dateOperators,
    getOperatorTypes,
  } = useOperators();

  const pickOperators = keys => keys.map(key => operators.value[key]);

  const buildFilterType = (attributeKey, labelKey, config) => ({
    attributeKey,
    value: attributeKey,
    attributeName: t(`DEALS.FIELDS.${labelKey}`),
    label: t(`DEALS.FIELDS.${labelKey}`),
    attributeModel: 'standard',
    ...config,
  });

  return computed(() => [
    buildFilterType('name', 'NAME', {
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
    }),
    buildFilterType('value', 'VALUE', {
      inputType: 'number',
      dataType: 'number',
      filterOperators: pickOperators([
        'equal_to',
        'not_equal_to',
        'is_greater_than',
        'is_less_than',
        'is_present',
        'is_not_present',
      ]),
    }),
    buildFilterType('stage_id', 'STAGE', {
      inputType: 'multiSelect',
      dataType: 'number',
      options: stages.value.map(stage => ({ id: stage.id, name: stage.name })),
      filterOperators: equalityOperators.value,
    }),
    buildFilterType('assignee_id', 'ASSIGNEE', {
      inputType: 'multiSelect',
      dataType: 'number',
      options: agents.value.map(agent => ({ id: agent.id, name: agent.name })),
      filterOperators: presenceOperators.value,
    }),
    buildFilterType('expected_close_date', 'EXPECTED_CLOSE_DATE', {
      inputType: 'date',
      dataType: 'date',
      filterOperators: pickOperators([
        'is_greater_than',
        'is_less_than',
        'is_present',
        'is_not_present',
      ]),
    }),
    buildFilterType('closed_at', 'CLOSED_AT', {
      inputType: 'date',
      dataType: 'date',
      filterOperators: [
        ...dateOperators.value,
        ...pickOperators(['is_present', 'is_not_present']),
      ],
    }),
    buildFilterType('created_at', 'CREATED_AT', {
      inputType: 'date',
      dataType: 'date',
      filterOperators: dateOperators.value,
    }),
    ...buildAttributesFilterTypes(
      dealAttributes.value,
      getOperatorTypes,
      'deal'
    ),
  ]);
}
