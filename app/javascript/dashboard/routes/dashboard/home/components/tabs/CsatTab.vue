<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { dynamicTime } from 'shared/helpers/timeHelper';
import DashboardCard from '../cards/DashboardCard.vue';
import MiniStat from '../cards/MiniStat.vue';
import CategoryBarChart from '../cards/CategoryBarChart.vue';
import { useChartTheme } from '../../composables/useChartTheme';
import { formatNumber, percent } from '../../helpers';

const props = defineProps({
  data: { type: Object, required: true },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { colors } = useChartTheme();

const RATINGS = [5, 4, 3, 2, 1];

const csat = computed(() => props.data.csat);
const ratingColors = computed(() => {
  const [brand, , amber, ruby] = colors.value.palette;
  return [brand, colors.value.palette[5], amber, ruby, ruby];
});

const averageDelta = computed(() => {
  const { average, previous_average: previous } = csat.value;
  if (average == null || previous == null) return '';
  const diff = Math.round((average - previous) * 100) / 100;
  return t('HOME.DASHBOARD.CSAT.VS_PREVIOUS', {
    value: diff > 0 ? `+${diff}` : diff,
  });
});

const openConversation = displayId =>
  displayId &&
  router.push({
    name: 'inbox_conversation',
    params: { accountId: route.params.accountId, conversation_id: displayId },
  });
</script>

<template>
  <div class="grid grid-cols-1 gap-5 lg:grid-cols-12">
    <div class="grid grid-cols-2 gap-3 lg:col-span-12 md:grid-cols-4">
      <MiniStat
        :label="t('HOME.DASHBOARD.CSAT.AVERAGE')"
        :value="csat.average ?? '—'"
        unit="/5"
        :hint="averageDelta"
        tone="brand"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CSAT.RESPONSES')"
        :value="formatNumber(csat.total)"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CSAT.FIVE_STAR')"
        :value="percent(csat.distribution[5] ?? 0, csat.total)"
        unit="%"
        tone="amber"
      />
      <MiniStat
        :label="t('HOME.DASHBOARD.CSAT.LOW')"
        :value="
          formatNumber(
            (csat.distribution[1] ?? 0) + (csat.distribution[2] ?? 0)
          )
        "
        tone="ruby"
      />
    </div>
    <DashboardCard
      :title="t('HOME.DASHBOARD.CSAT.CHART_TITLE')"
      :subtitle="t('HOME.DASHBOARD.CSAT.CHART_SUBTITLE')"
      icon="i-lucide-star"
      class="lg:col-span-7"
    >
      <CategoryBarChart
        horizontal
        :categories="RATINGS.map(rating => `${rating} ★`)"
        :values="RATINGS.map(rating => csat.distribution[rating] ?? 0)"
        :colors="ratingColors"
        :name="t('HOME.DASHBOARD.CSAT.RESPONSES')"
        :height="300"
      />
    </DashboardCard>
    <DashboardCard
      :title="t('HOME.DASHBOARD.CSAT.RECENT_TITLE')"
      :subtitle="t('HOME.DASHBOARD.CSAT.RECENT_SUBTITLE')"
      icon="i-lucide-message-square-quote"
      class="lg:col-span-5"
    >
      <p
        v-if="!csat.recent.length"
        class="py-8 text-sm text-center text-n-slate-11"
      >
        {{ t('HOME.DASHBOARD.EMPTY') }}
      </p>
      <ul v-else class="flex flex-col gap-2">
        <li
          v-for="response in csat.recent"
          :key="`${response.display_id}-${response.timestamp}`"
          class="flex flex-col gap-1 p-3 border cursor-pointer rounded-xl border-n-weak hover:bg-n-alpha-1"
          @click="openConversation(response.display_id)"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="text-[13px] font-semibold text-n-slate-12 truncate">
              {{ response.contact_name || t('HOME.ATTENTION.UNKNOWN_CONTACT') }}
            </span>
            <span class="flex items-center gap-0.5 shrink-0">
              <span
                v-for="star in 5"
                :key="star"
                class="i-ph-star-fill size-3"
                :class="
                  star <= response.rating ? 'text-n-amber-9' : 'text-n-slate-6'
                "
              />
            </span>
          </div>
          <p
            v-if="response.feedback"
            class="text-xs italic text-n-slate-11 line-clamp-2"
          >
            {{ response.feedback }}
          </p>
          <p class="text-[11px] text-n-slate-10">
            {{ dynamicTime(response.timestamp) }}
          </p>
        </li>
      </ul>
    </DashboardCard>
  </div>
</template>
