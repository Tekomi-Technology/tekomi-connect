import { computed, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useConfig } from 'dashboard/composables/useConfig';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export const AI_PANEL_TABS = Object.freeze({
  COPILOT: 'copilot',
  ANALYSIS: 'analysis',
});

const activeAiTab = ref(AI_PANEL_TABS.COPILOT);

export function useAiPanel() {
  const { isEnterprise } = useConfig();
  const currentAccountId = useMapGetter('getCurrentAccountId');
  const isFeatureEnabledonAccount = useMapGetter(
    'accounts/isFeatureEnabledonAccount'
  );

  const isAiAvailable = computed(
    () =>
      isEnterprise &&
      isFeatureEnabledonAccount.value(
        currentAccountId.value,
        FEATURE_FLAGS.TEKOMI
      )
  );

  return { activeAiTab, isAiAvailable };
}
