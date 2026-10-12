import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAiAlertsStore } from 'dashboard/stores/aiAlerts';

const TABS = [
  { key: 'setup', route: 'tekomi_settings_index', label: 'TABS.SETUP' },
  { key: 'models', route: 'tekomi_settings_models', label: 'TABS.MODELS' },
  {
    key: 'prompts',
    route: 'tekomi_settings_prompts',
    label: 'TABS.PROMPTS',
    activeOn: ['tekomi_settings_prompt'],
  },
  { key: 'alerts', route: 'tekomi_ai_alerts', label: 'TABS.ALERTS' },
];

export function useSettingsTabs() {
  const { t } = useI18n();
  const route = useRoute();
  const router = useRouter();
  const { accountId } = useAccount();
  const { meta: aiAlertsMeta } = storeToRefs(useAiAlertsStore());

  const tabs = computed(() =>
    TABS.map(tab => ({
      key: tab.key,
      label: t(`TEKOMI_SETTINGS.${tab.label}`),
      ...(tab.key === 'alerts'
        ? { count: aiAlertsMeta.value.unreadCount }
        : {}),
    }))
  );

  const activeTabIndex = computed(() =>
    TABS.findIndex(
      tab =>
        tab.route === route.name || (tab.activeOn || []).includes(route.name)
    )
  );

  const onTabChanged = tab => {
    const target = TABS.find(item => item.key === tab.key);
    router.push({ name: target.route, params: { accountId: accountId.value } });
  };

  return { tabs, activeTabIndex, onTabChanged };
}
