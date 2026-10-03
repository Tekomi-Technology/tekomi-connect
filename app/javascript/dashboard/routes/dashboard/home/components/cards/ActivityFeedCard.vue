<script setup>
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { dynamicTime } from 'shared/helpers/timeHelper';
import DashboardCard from './DashboardCard.vue';

defineProps({
  events: { type: Array, default: () => [] },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const EVENT_STYLES = {
  resolved: { dot: 'bg-n-teal-9', icon: 'i-lucide-circle-check-big' },
  starred_waiting: { dot: 'bg-n-amber-9', icon: 'i-ph-star-fill' },
  sla_missed: { dot: 'bg-n-ruby-9', icon: 'i-lucide-siren' },
  csat: { dot: 'bg-n-violet-9', icon: 'i-lucide-smile' },
};

const openConversation = event => {
  if (!event.display_id) return;
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: event.display_id,
    },
  });
};
</script>

<template>
  <DashboardCard
    :title="title || t('HOME.DASHBOARD.ACTIVITY.TITLE')"
    :subtitle="subtitle || t('HOME.DASHBOARD.ACTIVITY.SUBTITLE')"
    icon="i-lucide-history"
  >
    <p v-if="!events.length" class="py-8 text-sm text-center text-n-slate-11">
      {{ t('HOME.DASHBOARD.EMPTY') }}
    </p>
    <ol v-else class="relative flex flex-col gap-1">
      <span
        class="absolute top-2 bottom-2 w-px ltr:left-[11px] rtl:right-[11px] bg-n-weak"
      />
      <li
        v-for="(event, index) in events"
        :key="`${event.type}-${event.display_id}-${index}`"
        class="relative flex gap-3 p-1.5 rounded-xl cursor-pointer hover:bg-n-alpha-1"
        @click="openConversation(event)"
      >
        <span
          class="relative z-10 flex items-center justify-center rounded-full size-6 shrink-0 ring-4 ring-white dark:ring-n-solid-2"
          :class="EVENT_STYLES[event.type].dot"
        >
          <span
            class="text-white size-3"
            :class="EVENT_STYLES[event.type].icon"
          />
        </span>
        <div class="min-w-0">
          <p class="text-[13px] font-semibold text-n-slate-12">
            {{
              t(`HOME.DASHBOARD.ACTIVITY.${event.type.toUpperCase()}`, {
                id: event.display_id,
                rating: event.rating,
              })
            }}
          </p>
          <p class="text-xs truncate text-n-slate-11">
            {{
              event.feedback ||
              event.contact_name ||
              t('HOME.ATTENTION.UNKNOWN_CONTACT')
            }}
          </p>
          <p class="text-[11px] text-n-slate-10">
            {{ dynamicTime(event.timestamp) }}
          </p>
        </div>
      </li>
    </ol>
  </DashboardCard>
</template>
