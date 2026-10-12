<script setup>
import { useI18n } from 'vue-i18n';
import { useTekomi } from 'dashboard/composables/useTekomi';
import { useSettingsTabs } from './useSettingsTabs';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import TekomiPaywall from 'next/tekomi/pageComponents/Paywall.vue';

defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const { tekomiEnabled } = useTekomi();
const { tabs, activeTabIndex, onTabChanged } = useSettingsTabs();
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :no-records-message="t('TEKOMI_SETTINGS.NOT_ENABLED')"
    :loading-message="t('TEKOMI_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TEKOMI_SETTINGS.TITLE')"
        :description="t('TEKOMI_SETTINGS.DESCRIPTION')"
        :link-text="t('TEKOMI_SETTINGS.LINK_TEXT')"
        icon-name="tekomi"
        feature-name="tekomi_billing"
      >
        <template #tabs>
          <TabBar
            :tabs="tabs"
            :initial-active-tab="activeTabIndex"
            @tab-changed="onTabChanged"
          />
        </template>
        <template #actions>
          <slot name="actions" />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <slot v-if="tekomiEnabled" />
      <TekomiPaywall v-else />
    </template>
  </SettingsLayout>
</template>
