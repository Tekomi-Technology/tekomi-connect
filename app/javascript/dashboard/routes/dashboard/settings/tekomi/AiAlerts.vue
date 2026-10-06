<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAiAlertsStore } from 'dashboard/stores/aiAlerts';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { accountId } = useAccount();
const aiAlertsStore = useAiAlertsStore();
const { records, meta, uiFlags } = storeToRefs(aiAlertsStore);

const tabs = computed(() => [
  { key: 'settings', label: t('TEKOMI_SETTINGS.TABS.SETTINGS') },
  {
    key: 'alerts',
    label: t('TEKOMI_SETTINGS.TABS.ALERTS'),
    count: meta.value.unreadCount,
  },
]);

const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab =>
    tab.key === 'alerts'
      ? route.name === 'tekomi_ai_alerts'
      : route.name === 'tekomi_settings_index'
  )
);

const categoryClass = category =>
  ({
    configuration: 'bg-n-amber-3 text-n-amber-11',
    authentication: 'bg-n-ruby-3 text-n-ruby-11',
    quota: 'bg-n-amber-3 text-n-amber-11',
    availability: 'bg-n-blue-3 text-n-blue-11',
    provider: 'bg-n-purple-3 text-n-purple-11',
    unknown: 'bg-n-slate-3 text-n-slate-11',
  }[category] || 'bg-n-slate-3 text-n-slate-11');

const formatDate = value => {
  if (!value) return '';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
};

const onTabChanged = tab => {
  router.push({
    name: tab.key === 'alerts' ? 'tekomi_ai_alerts' : 'tekomi_settings_index',
    params: { accountId: accountId.value },
  });
};

const markRead = async alert => {
  try {
    await aiAlertsStore.markRead(alert.id, !alert.readAt);
  } catch {
    useAlert(t('TEKOMI_SETTINGS.ALERTS.API.ERROR'));
  }
};

const markAllRead = async () => {
  try {
    await aiAlertsStore.markAllRead();
  } catch {
    useAlert(t('TEKOMI_SETTINGS.ALERTS.API.ERROR'));
  }
};

const remove = async alert => {
  try {
    await aiAlertsStore.remove(alert.id);
  } catch {
    useAlert(t('TEKOMI_SETTINGS.ALERTS.API.ERROR'));
  }
};

onMounted(() => aiAlertsStore.fetch());
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="t('TEKOMI_SETTINGS.ALERTS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TEKOMI_SETTINGS.ALERTS.TITLE')"
        :description="t('TEKOMI_SETTINGS.ALERTS.DESCRIPTION')"
        icon-name="tekomi"
      >
        <template #tabs>
          <TabBar
            :tabs="tabs"
            :initial-active-tab="activeTabIndex"
            @tab-changed="onTabChanged"
          />
        </template>
        <template #actions>
          <Button
            v-if="meta.unreadCount"
            ghost
            slate
            size="sm"
            :disabled="uiFlags.isUpdating"
            @click="markAllRead"
          >
            {{ t('TEKOMI_SETTINGS.ALERTS.MARK_ALL_READ') }}
          </Button>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="grid gap-3">
        <div
          v-for="alert in records"
          :key="alert.id"
          class="flex flex-col gap-3 p-4 bg-white border rounded-xl border-n-weak dark:bg-n-solid-2"
          :class="{ 'opacity-70': alert.readAt }"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="flex items-start min-w-0 gap-3">
              <Icon
                icon="i-lucide-triangle-alert"
                class="mt-0.5 flex-shrink-0 size-5 text-n-red-11"
              />
              <div class="min-w-0">
                <p class="text-sm font-semibold text-n-slate-12">
                  {{ alert.title }}
                </p>
                <p class="mt-1 text-xs text-n-slate-10">
                  {{ formatDate(alert.lastSeenAt || alert.createdAt) }}
                  <span v-if="alert.occurrences > 1">
                    · {{ t('TEKOMI_SETTINGS.ALERTS.OCCURRENCES', { count: alert.occurrences }) }}
                  </span>
                </p>
              </div>
            </div>
            <span
              class="px-2 py-1 text-xs font-medium rounded-lg whitespace-nowrap"
              :class="categoryClass(alert.category)"
            >
              {{ t(`TEKOMI_SETTINGS.ALERTS.CATEGORIES.${alert.category.toUpperCase()}`) }}
            </span>
          </div>
          <p class="text-sm break-words whitespace-pre-wrap text-n-slate-11">
            {{ alert.message }}
          </p>
          <div class="flex flex-wrap items-center gap-2 text-xs text-n-slate-10">
            <span v-if="alert.feature">{{ alert.feature }}</span>
            <span v-if="alert.provider">· {{ alert.provider }}</span>
            <span v-if="alert.statusCode">· HTTP {{ alert.statusCode }}</span>
            <span v-if="alert.readAt">· {{ t('TEKOMI_SETTINGS.ALERTS.READ') }}</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <Button
              ghost
              slate
              size="sm"
              :disabled="uiFlags.isUpdating"
              @click="markRead(alert)"
            >
              {{ alert.readAt ? t('TEKOMI_SETTINGS.ALERTS.MARK_UNREAD') : t('TEKOMI_SETTINGS.ALERTS.MARK_READ') }}
            </Button>
            <Button
              ghost
              slate
              size="sm"
              :disabled="uiFlags.isDeleting"
              @click="remove(alert)"
            >
              {{ t('TEKOMI_SETTINGS.ALERTS.DELETE') }}
            </Button>
          </div>
        </div>
        <div
          v-if="!uiFlags.isFetching && !records.length"
          class="p-10 text-sm text-center border rounded-xl border-n-weak text-n-slate-10"
        >
          {{ t('TEKOMI_SETTINGS.ALERTS.EMPTY') }}
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
