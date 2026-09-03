<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { getUserPermissions } from 'dashboard/helper/permissionsHelper';
import MyStatsRow from './components/MyStatsRow.vue';
import NeedsAttentionList from './components/NeedsAttentionList.vue';
import MyWeekCard from './components/MyWeekCard.vue';
import AccountSnapshotCard from './components/AccountSnapshotCard.vue';

const { t } = useI18n();
const route = useRoute();
const currentUser = useMapGetter('getCurrentUser');

const greeting = computed(() =>
  t('HOME.GREETING', { name: currentUser.value?.available_name ?? '' })
);

// `ReportPolicy#view?` is `@account_user.administrator?`, widened by
// `Enterprise::ReportPolicy` to `custom_role&.permissions&.include?('report_manage') || super`.
// So the gate here must be BOTH permissions, matching the Reports routes'
// `permissions: ['administrator', 'report_manage']`
// (routes/dashboard/settings/reports/reports.routes.js) -- gating on
// `report_manage` alone would hide this from ordinary administrators, who
// usually hold no custom role at all.
const canSeeAccountStats = computed(() => {
  const permissions = getUserPermissions(
    currentUser.value,
    route.params.accountId
  );
  return permissions.some(permission =>
    ['administrator', 'report_manage'].includes(permission)
  );
});
</script>

<template>
  <main
    class="flex flex-col w-full h-full gap-4 p-6 overflow-y-auto bg-n-solid-1"
  >
    <header class="flex items-start justify-between gap-4">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('HOME.TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">{{ greeting }}</p>
      </div>
    </header>

    <MyStatsRow />
    <div class="flex flex-col gap-4 lg:flex-row">
      <div class="lg:w-2/3">
        <NeedsAttentionList />
      </div>
      <div class="flex flex-col gap-4 lg:w-1/3">
        <MyWeekCard />
        <AccountSnapshotCard v-if="canSeeAccountStats" />
      </div>
    </div>
  </main>
</template>
