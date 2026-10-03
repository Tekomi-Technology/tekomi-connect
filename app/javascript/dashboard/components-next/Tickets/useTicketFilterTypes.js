import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useOperators } from 'dashboard/components-next/filter/operators';
import { buildAttributesFilterTypes } from 'dashboard/components-next/filter/helper/filterHelper';
import { SLA_STATUSES } from './constants';
import { useTicketFields } from './useTicketFields';

export function useTicketFilterTypes(stages) {
  const { t } = useI18n();
  const agents = useMapGetter('agents/getAgents');
  const { ticketAttributes } = useTicketFields();
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
    attributeName: t(`TICKETS.FIELDS.${labelKey}`),
    label: t(`TICKETS.FIELDS.${labelKey}`),
    attributeModel: 'standard',
    ...config,
  });

  return computed(() => [
    buildFilterType('title', 'TITLE', {
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: containmentOperators.value,
    }),
    buildFilterType('description', 'DESCRIPTION', {
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: [
        ...containmentOperators.value,
        ...pickOperators(['is_present', 'is_not_present']),
      ],
    }),
    buildFilterType('stage_id', 'STAGE', {
      inputType: 'multiSelect',
      dataType: 'number',
      options: stages.value.map(stage => ({ id: stage.id, name: stage.name })),
      filterOperators: equalityOperators.value,
    }),
    buildFilterType('sla_status', 'SLA', {
      inputType: 'multiSelect',
      dataType: 'text',
      options: Object.values(SLA_STATUSES).map(status => ({
        id: status,
        name: t(`TICKETS.SLA_STATUS.${status.toUpperCase()}`),
      })),
      filterOperators: equalityOperators.value,
    }),
    buildFilterType('assignee_id', 'ASSIGNEE', {
      inputType: 'multiSelect',
      dataType: 'number',
      options: agents.value.map(agent => ({ id: agent.id, name: agent.name })),
      filterOperators: presenceOperators.value,
    }),
    buildFilterType('contact_id', 'CONTACT', {
      inputType: 'number',
      dataType: 'number',
      filterOperators: presenceOperators.value,
    }),
    buildFilterType('created_by', 'CREATED_BY', {
      inputType: 'multiSelect',
      dataType: 'text',
      options: ['staff', 'ai_chatbot', 'ai_callbot', 'webhook'].map(source => ({
        id: source,
        name: t(`TICKETS.CREATED_BY.${source.toUpperCase()}`),
      })),
      filterOperators: equalityOperators.value,
    }),
    buildFilterType('created_at', 'CREATED_AT', {
      inputType: 'date',
      dataType: 'date',
      filterOperators: dateOperators.value,
    }),
    ...buildAttributesFilterTypes(
      ticketAttributes.value,
      getOperatorTypes,
      'ticket'
    ),
  ]);
}
