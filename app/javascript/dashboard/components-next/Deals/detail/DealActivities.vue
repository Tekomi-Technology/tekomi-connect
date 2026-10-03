<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import DealsAPI from 'dashboard/api/deals';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatVND } from '../constants';

const props = defineProps({
  deal: { type: Object, required: true },
});

const { t } = useI18n();
const pipelinesStore = usePipelinesStore();
const agents = useMapGetter('agents/getAgents');

const activities = ref([]);
const isLoading = ref(false);

const stageNames = computed(() =>
  Object.fromEntries(
    pipelinesStore.records.flatMap(pipeline =>
      pipeline.stages.map(stage => [stage.id, stage.name])
    )
  )
);

const agentName = id =>
  agents.value.find(agent => agent.id === id)?.name || t('DEALS.UNASSIGNED');

const describe = ({ action, metadata, actor }) => {
  const actorName = actor?.name || t('DEALS.DETAIL.ACTIVITY.SYSTEM');
  const formatters = {
    stage_changed: value => stageNames.value[value] || '—',
    value_changed: value =>
      value === null ? t('DEALS.NO_VALUE') : formatVND(value),
    assignee_changed: value => (value ? agentName(value) : t('DEALS.UNASSIGNED')),
  };
  const format = formatters[action];
  return t(`DEALS.DETAIL.ACTIVITY.${action.toUpperCase()}`, {
    actor: actorName,
    from: format ? format(metadata.from) : '',
    to: format ? format(metadata.to) : '',
  });
};

const loadActivities = async () => {
  isLoading.value = true;
  try {
    const { data } = await DealsAPI.getActivities(props.deal.id);
    activities.value = camelcaseKeys(data.payload, {
      deep: true,
      stopPaths: ['metadata'],
    });
  } catch {
    useAlert(t('DEALS.DETAIL.ACTIVITY.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch(() => [props.deal.id, props.deal.updatedAt], loadActivities, {
  immediate: true,
});
</script>

<template>
  <div v-if="isLoading && !activities.length" class="flex justify-center py-4">
    <Spinner :size="20" />
  </div>
  <ul v-else class="flex flex-col gap-3 list-none">
    <li
      v-for="activity in activities"
      :key="activity.id"
      class="flex items-start gap-2 text-sm"
    >
      <Avatar
        :name="activity.actor?.name || t('DEALS.DETAIL.ACTIVITY.SYSTEM')"
        :src="activity.actor?.thumbnail"
        :size="20"
        rounded-full
      />
      <div class="flex flex-col min-w-0">
        <span class="text-n-slate-12">{{ describe(activity) }}</span>
        <span class="text-xs text-n-slate-11">
          {{ dynamicTime(activity.createdAt) }}
        </span>
      </div>
    </li>
  </ul>
</template>
