<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { getUserPermissions } from 'dashboard/helper/permissionsHelper';
import MyStatsRow from './components/MyStatsRow.vue';
import NeedsAttentionList from './components/NeedsAttentionList.vue';
import MyWeekCard from './components/MyWeekCard.vue';
import AccountSnapshotCard from './components/AccountSnapshotCard.vue';

const route = useRoute();
const currentUser = useMapGetter('getCurrentUser');

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
    class="flex flex-col w-full h-full gap-6 p-6 overflow-y-auto bg-n-background"
  >
    <MyStatsRow />
    <div class="grid grid-cols-1 gap-6 xl:grid-cols-3">
      <div class="min-w-0 xl:col-span-2">
        <NeedsAttentionList />
      </div>
      <div class="flex flex-col gap-6 min-w-0">
        <MyWeekCard />
        <AccountSnapshotCard v-if="canSeeAccountStats" />
      </div>
    </div>
  </main>
</template>
