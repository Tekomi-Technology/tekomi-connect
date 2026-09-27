// Route query value (`?filter=vip`) that opens the conversation list with the
// open-VIP filter already applied, used by the Home "Needs attention" card.
export const VIP_FILTER_QUERY_VALUE = 'vip';

/**
 * Open conversations of VIP contacts, in the advanced filter modal shape
 * (camelCase keys, option objects as values) so the applied filter can be
 * edited in the modal like one the agent built by hand.
 */
export const buildOpenVipConversationFilters = ({ openLabel, vipLabel }) => [
  {
    attributeKey: 'status',
    filterOperator: 'equal_to',
    values: [{ id: 'open', name: openLabel }],
    queryOperator: 'and',
    attributeModel: 'standard',
  },
  {
    attributeKey: 'contact_vip',
    filterOperator: 'equal_to',
    values: { id: true, name: vipLabel },
    queryOperator: 'and',
    attributeModel: 'standard',
  },
];
