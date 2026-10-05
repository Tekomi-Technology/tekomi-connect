<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import DashboardHeader from './components/DashboardHeader.vue';
import KpiTabs from './components/KpiTabs.vue';
import OverviewTab from './components/tabs/OverviewTab.vue';
import ConversationsTab from './components/tabs/ConversationsTab.vue';
import ResolvedTab from './components/tabs/ResolvedTab.vue';
import ResponseTab from './components/tabs/ResponseTab.vue';
import CsatTab from './components/tabs/CsatTab.vue';
import SlaTab from './components/tabs/SlaTab.vue';
import ChannelsTab from './components/tabs/ChannelsTab.vue';
import { useOverviewDashboard } from './composables/useOverviewDashboard';

// Order matches the KPI tiles; it decides which way the stage slides.
const TABS = [
  { key: 'overview', component: OverviewTab, withGroupBy: true },
  {
    key: 'conversations',
    component: ConversationsTab,
    withGroupBy: true,
    withDays: true,
  },
  { key: 'resolved', component: ResolvedTab, withGroupBy: true },
  { key: 'response', component: ResponseTab, withGroupBy: true },
  { key: 'csat', component: CsatTab },
  { key: 'sla', component: SlaTab, withGroupBy: true },
  { key: 'channels', component: ChannelsTab },
];

const TRANSITIONS = {
  forward: {
    enterFrom:
      'opacity-0 [transform:translateX(56px)_rotateY(-10deg)_scale(0.97)]',
    leaveTo:
      'opacity-0 [transform:translateX(-56px)_rotateY(10deg)_scale(0.97)]',
  },
  backward: {
    enterFrom:
      'opacity-0 [transform:translateX(-56px)_rotateY(10deg)_scale(0.97)]',
    leaveTo:
      'opacity-0 [transform:translateX(56px)_rotateY(-10deg)_scale(0.97)]',
  },
};

const { t } = useI18n();
const {
  period,
  inboxId,
  data,
  range,
  days,
  isLoading,
  hasError,
  updatedAt,
  load,
} = useOverviewDashboard();

const activeTab = ref('overview');
const direction = ref('forward');

const selectTab = key => {
  const from = TABS.findIndex(tab => tab.key === activeTab.value);
  const to = TABS.findIndex(tab => tab.key === key);
  direction.value = to >= from ? 'forward' : 'backward';
  activeTab.value = key;
};

const activeTabModel = computed({
  get: () => activeTab.value,
  set: selectTab,
});

const stage = computed(() => {
  const tab = TABS.find(item => item.key === activeTab.value);
  return {
    component: tab.component,
    props: {
      data: data.value,
      ...(tab.withGroupBy && { groupBy: range.value.groupBy }),
      ...(tab.withDays && { days: days.value }),
    },
  };
});

const transition = computed(() => TRANSITIONS[direction.value]);

onMounted(load);
</script>

<template>
  <main
    class="flex flex-col w-full h-full gap-5 p-6 overflow-x-hidden overflow-y-auto bg-n-background no-scrollbar"
  >
    <DashboardHeader
      v-model:period="period"
      v-model:inbox-id="inboxId"
      :updated-at="updatedAt"
      :is-loading="isLoading"
      @refresh="load"
    />

    <KpiTabs v-model="activeTabModel" :data="data" :direction="direction" />

    <div
      v-if="!data && isLoading"
      class="grid grid-cols-1 gap-5 lg:grid-cols-12"
    >
      <div
        v-for="span in [
          'lg:col-span-5',
          'lg:col-span-4',
          'lg:col-span-3',
          'lg:col-span-8',
          'lg:col-span-4',
        ]"
        :key="span"
        class="h-64 rounded-2xl bg-n-alpha-2 animate-pulse"
        :class="span"
      />
    </div>

    <div
      v-else-if="!data && hasError"
      class="flex flex-col items-center gap-3 py-16 text-sm text-n-slate-11"
    >
      {{ t('HOME.DASHBOARD.ERROR') }}
      <button
        type="button"
        class="font-medium text-n-brand hover:underline"
        @click="load"
      >
        {{ t('HOME.RETRY') }}
      </button>
    </div>

    <div
      v-else-if="data"
      class="grid [perspective:1600px] transition-opacity duration-300"
      :class="{ 'opacity-60': isLoading }"
    >
      <Transition
        enter-active-class="transition-all duration-500 ease-out motion-reduce:transition-none"
        :enter-from-class="transition.enterFrom"
        leave-active-class="transition-all duration-300 ease-in pointer-events-none motion-reduce:transition-none"
        :leave-to-class="transition.leaveTo"
      >
        <component
          :is="stage.component"
          :key="activeTab"
          v-bind="stage.props"
          class="col-start-1 row-start-1 min-w-0 origin-center"
        />
      </Transition>
    </div>
  </main>
</template>
