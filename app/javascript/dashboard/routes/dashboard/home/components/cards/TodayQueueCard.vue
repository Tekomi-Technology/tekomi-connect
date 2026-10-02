<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import DashboardCard from './DashboardCard.vue';
import MiniStat from './MiniStat.vue';
import { formatNumber } from '../../helpers';

defineProps({
  live: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const route = useRoute();
</script>

<template>
  <DashboardCard
    :title="t('HOME.DASHBOARD.QUEUE.TITLE')"
    :subtitle="t('HOME.DASHBOARD.QUEUE.SUBTITLE')"
    icon="i-lucide-inbox"
  >
    <template v-if="live.unattended" #action>
      <span
        class="flex items-center gap-1 px-2 py-0.5 rounded-full bg-n-ruby-3 text-n-ruby-11 text-[11px] font-semibold"
      >
        <span class="rounded-full size-1.5 bg-n-ruby-9 animate-pulse" />
        {{ t('HOME.DASHBOARD.QUEUE.URGENT') }}
      </span>
    </template>
    <div class="grid grid-cols-3 gap-2">
      <MiniStat
        :label="t('HOME.DASHBOARD.QUEUE.UNATTENDED')"
        :value="formatNumber(live.unattended)"
        :hint="t('HOME.DASHBOARD.QUEUE.UNATTENDED_HINT')"
        tone="ruby"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.QUEUE.STARRED')"
        :value="formatNumber(live.starred_waiting)"
        :hint="t('HOME.DASHBOARD.QUEUE.STARRED_HINT')"
        tone="amber"
      >
        <template #label>
          <span class="flex items-center gap-1">
            {{ t('HOME.DASHBOARD.QUEUE.STARRED') }}
            <span class="i-ph-star-fill size-3 text-n-amber-9" />
          </span>
        </template>
      </MiniStat>
      <MiniStat
        :label="t('HOME.DASHBOARD.QUEUE.UNASSIGNED')"
        :value="formatNumber(live.unassigned)"
        :hint="t('HOME.DASHBOARD.QUEUE.UNASSIGNED_HINT')"
        tone="violet"
      />
    </div>
    <router-link
      :to="{ name: 'home', params: { accountId: route.params.accountId } }"
      class="flex items-center justify-center gap-2 py-3 mt-auto text-sm font-semibold text-white transition-all duration-200 shadow-sm rounded-xl bg-n-brand hover:brightness-110 hover:shadow-md active:scale-[0.98]"
    >
      {{ t('HOME.DASHBOARD.QUEUE.OPEN_INBOX') }}
      <span class="i-lucide-arrow-right size-4" />
    </router-link>
  </DashboardCard>
</template>
