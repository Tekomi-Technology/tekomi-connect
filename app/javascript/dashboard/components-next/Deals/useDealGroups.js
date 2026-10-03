import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

export function useDealGroups(deals, groupBy, stages) {
  const { t } = useI18n();

  return computed(() => {
    if (groupBy.value === 'stage') {
      return stages.value.map(stage => ({
        key: `stage-${stage.id}`,
        label: stage.name,
        color: stage.color,
        deals: deals.value.filter(deal => deal.stageId === stage.id),
      }));
    }
    if (groupBy.value === 'assignee') {
      const groups = new Map();
      deals.value.forEach(deal => {
        const key = `assignee-${deal.assignee?.id || 'none'}`;
        if (!groups.has(key)) {
          groups.set(key, {
            key,
            label: deal.assignee?.name || t('DEALS.UNASSIGNED'),
            deals: [],
          });
        }
        groups.get(key).deals.push(deal);
      });
      return [...groups.values()];
    }
    return [{ key: 'all', label: '', deals: deals.value }];
  });
}
