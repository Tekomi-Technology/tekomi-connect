import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import filterQueryGenerator from '../filterQueryGenerator';
import { buildOpenVipConversationFilters } from '../vipConversationFilter';

describe('buildOpenVipConversationFilters', () => {
  const filters = buildOpenVipConversationFilters({
    openLabel: 'Open',
    vipLabel: 'True',
  });

  it('builds modal-shaped filters for open conversations of VIP contacts', () => {
    expect(filters).toEqual([
      expect.objectContaining({
        attributeKey: 'status',
        filterOperator: 'equal_to',
        values: [{ id: 'open', name: 'Open' }],
      }),
      expect.objectContaining({
        attributeKey: 'contact_vip',
        filterOperator: 'equal_to',
        values: { id: true, name: 'True' },
      }),
    ]);
  });

  it('generates the payload the conversation filter API expects', () => {
    expect(filterQueryGenerator(useSnakeCase(filters))).toEqual({
      payload: [
        {
          attribute_key: 'status',
          filter_operator: 'equal_to',
          values: ['open'],
          query_operator: 'and',
          attribute_model: 'standard',
        },
        {
          attribute_key: 'contact_vip',
          filter_operator: 'equal_to',
          values: [true],
          query_operator: undefined,
          attribute_model: 'standard',
        },
      ],
    });
  });
});
