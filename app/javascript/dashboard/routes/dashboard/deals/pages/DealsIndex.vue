<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { usePipelinesStore } from 'dashboard/stores/pipelines';
import { useSavedViewsStore } from 'dashboard/stores/savedViews';
import { useDealsStore } from 'dashboard/stores/deals';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ViewPicker from 'dashboard/components-next/Deals/ViewPicker.vue';
import SavedViewDialog from 'dashboard/components-next/Deals/SavedViewDialog.vue';
import DealsFilter from 'dashboard/components-next/Deals/DealsFilter.vue';
import DealsSortMenu from 'dashboard/components-next/Deals/DealsSortMenu.vue';
import DealsViewOptions from 'dashboard/components-next/Deals/DealsViewOptions.vue';
import DealFormDialog from 'dashboard/components-next/Deals/DealFormDialog.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import DealsAiPanel from 'dashboard/components-next/Deals/ai/DealsAiPanel.vue';
import DealSuggestionsDialog from 'dashboard/components-next/Deals/ai/DealSuggestionsDialog.vue';
import DealDetail from 'dashboard/components-next/Deals/detail/DealDetail.vue';
import DealsListView from 'dashboard/components-next/Deals/views/DealsListView.vue';
import DealsKanbanView from 'dashboard/components-next/Deals/views/DealsKanbanView.vue';
import DealsTableView from 'dashboard/components-next/Deals/views/DealsTableView.vue';
import DealsCalendarView from 'dashboard/components-next/Deals/views/DealsCalendarView.vue';
import { useDealFilterTypes } from 'dashboard/components-next/Deals/useDealFilterTypes';
import { useDealFields } from 'dashboard/components-next/Deals/useDealFields';
import {
  VIEW_TYPES,
  normalizeFields,
  visibleFields,
} from 'dashboard/components-next/Deals/constants';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const pipelinesStore = usePipelinesStore();
const savedViewsStore = useSavedViewsStore();
const dealsStore = useDealsStore();
const agents = useMapGetter('agents/getAgents');
const { dealAttributes } = useDealFields();
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const accountId = useMapGetter('getCurrentAccountId');

const savedViewDialogRef = ref(null);
const deleteViewDialogRef = ref(null);
const dealFormDialogRef = ref(null);
const deleteDealsDialogRef = ref(null);
const pendingDeleteDeals = ref([]);
const calendarRange = ref(null);
const dealPanelRef = ref(null);
const panelDealId = ref(null);
const editingView = ref(null);
const showFilters = ref(false);
const showAiPanel = ref(false);
const dealSuggestionsDialogRef = ref(null);
const draftFilters = ref([]);

const pipelineId = computed(() => Number(route.params.pipelineId) || null);
const pipeline = computed(() =>
  pipelinesStore.getPipeline(pipelineId.value)
);
const stages = computed(() => pipeline.value?.stages || []);
const views = computed(() => savedViewsStore.records);
const activeView = computed(
  () =>
    savedViewsStore.getView(route.query.viewId) || savedViewsStore.records[0]
);
const activeFields = computed(() =>
  visibleFields(activeView.value, dealAttributes.value)
);
const tableFields = computed(() =>
  normalizeFields(activeView.value, dealAttributes.value)
);
const isManualOrder = computed(() => !activeView.value?.sorts?.length);
const panelDeal = computed(
  () =>
    dealsStore.records.find(deal => deal.id === panelDealId.value) ||
    dealsStore.undatedRecords.find(deal => deal.id === panelDealId.value) ||
    dealsStore.watchedDeal
);
const filterTypes = useDealFilterTypes(stages);
const hasActiveFilters = computed(() => !!activeView.value?.filters?.length);
const hasDealsAi = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.CRM_DEALS_AI)
);

const openPipelineFallback = () => {
  const [firstPipeline] = pipelinesStore.records;
  if (!pipeline.value && firstPipeline) {
    router.replace({
      name: 'deals_pipeline_index',
      params: { pipelineId: firstPipeline.id },
    });
  }
};

const selectView = viewId => {
  calendarRange.value = null;
  router.replace({ query: { ...route.query, viewId } });
};

const updateActiveView = async attributes => {
  try {
    await savedViewsStore.update(activeView.value.id, attributes);
  } catch {
    useAlert(t('DEALS.VIEWS.MESSAGES.SAVE_ERROR'));
  }
};

const openCreateView = () => {
  editingView.value = null;
  savedViewDialogRef.value?.open();
};

const openRenameView = view => {
  editingView.value = view;
  savedViewDialogRef.value?.open(view);
};

const saveView = async ({ name, viewType }) => {
  try {
    if (editingView.value) {
      await savedViewsStore.update(editingView.value.id, { name });
    } else {
      const view = await savedViewsStore.create({
        name,
        viewType,
        pipelineId: pipelineId.value,
      });
      selectView(view.id);
    }
    savedViewDialogRef.value?.close();
  } catch {
    useAlert(t('DEALS.VIEWS.MESSAGES.SAVE_ERROR'));
  }
};

const duplicateView = async view => {
  try {
    const copy = await savedViewsStore.create({
      name: t('DEALS.VIEWS.DUPLICATE_SUFFIX', { name: view.name }),
      viewType: view.viewType,
      pipelineId: view.pipelineId,
      icon: view.icon,
      groupBy: view.groupBy,
      filters: view.filters,
      sorts: view.sorts,
      fields: view.fields,
      settings: view.settings,
    });
    selectView(copy.id);
  } catch {
    useAlert(t('DEALS.VIEWS.MESSAGES.SAVE_ERROR'));
  }
};

const openDeleteView = view => {
  editingView.value = view;
  deleteViewDialogRef.value?.open();
};

const deleteView = async () => {
  try {
    await savedViewsStore.delete(editingView.value.id);
    deleteViewDialogRef.value?.close();
    selectView(savedViewsStore.records[0]?.id);
    useAlert(t('DEALS.VIEWS.MESSAGES.DELETE_SUCCESS'));
  } catch {
    useAlert(t('DEALS.VIEWS.MESSAGES.DELETE_ERROR'));
  }
};

const toggleFilters = () => {
  draftFilters.value = hasActiveFilters.value
    ? activeView.value.filters.map(filter => ({
        attributeKey: filter.attribute_key,
        filterOperator: filter.filter_operator,
        values: filter.values,
        queryOperator: filter.query_operator || 'and',
        attributeModel: filter.attribute_model,
      }))
    : [
        {
          attributeKey: 'name',
          filterOperator: 'contains',
          values: '',
          queryOperator: 'and',
          attributeModel: 'standard',
        },
      ];
  showFilters.value = !showFilters.value;
};

const applyFilters = filters => {
  showFilters.value = false;
  updateActiveView({ filters: useSnakeCase(filters, { deep: false }) });
};

const alertError = error => useAlert(error.message);

const loadMoreDeals = () => {
  dealsStore.fetchMore().catch(alertError);
};

const loadMoreInStage = stageId => {
  dealsStore.fetchMoreInStage(stageId).catch(alertError);
};

const updateDeal = ({ deal, changes }) => {
  dealsStore.update(deal, changes).catch(alertError);
};

const moveDeal = ({ deal, stageId, afterId, position }) => {
  const topPosition =
    Math.min(
      0,
      ...dealsStore.records
        .filter(record => record.stageId === stageId)
        .map(record => record.position)
    ) - 1;
  dealsStore
    .move(deal, { stageId, afterId, position: position ?? topPosition })
    .catch(alertError);
};

const requestDeleteDeals = deals => {
  pendingDeleteDeals.value = deals;
  deleteDealsDialogRef.value?.open();
};

const closeDealPanel = () => {
  panelDealId.value = null;
  dealsStore.unwatchDeal();
};

const openDeal = deal => {
  if (activeView.value?.settings?.open_in === 'page') {
    router.push({ name: 'deals_show', params: { dealId: deal.id } });
    return;
  }
  panelDealId.value = deal.id;
  dealsStore.watchDeal(deal);
  dealPanelRef.value?.open();
};

const deleteDeals = async () => {
  deleteDealsDialogRef.value?.close();
  if (pendingDeleteDeals.value.some(deal => deal.id === panelDealId.value)) {
    dealPanelRef.value?.close();
  }
  try {
    await Promise.all(
      pendingDeleteDeals.value.map(deal => dealsStore.delete(deal))
    );
    useAlert(t('DEALS.MESSAGES.DELETE_SUCCESS'));
  } catch {
    useAlert(t('DEALS.MESSAGES.DELETE_ERROR'));
  }
};

const openCreateDeal = (defaults = {}) => {
  dealFormDialogRef.value?.open(defaults);
};

const fetchDeals = () => {
  const view = activeView.value;
  if (!view) return;
  const query = {
    pipelineId: pipelineId.value,
    filters: view.filters,
    sorts: view.sorts,
  };
  if (view.viewType === VIEW_TYPES.KANBAN) {
    dealsStore
      .fetchKanban(
        query,
        stages.value.map(stage => stage.id)
      )
      .catch(alertError);
  } else if (view.viewType === VIEW_TYPES.CALENDAR) {
    if (calendarRange.value) {
      dealsStore.fetchCalendar(query, calendarRange.value).catch(alertError);
    }
  } else {
    dealsStore.fetch(query).catch(alertError);
  }
};

const createDeal = async deal => {
  try {
    await dealsStore.create(deal);
    dealFormDialogRef.value?.close();
    useAlert(t('DEALS.FORM.MESSAGES.SUCCESS'));
  } catch {
    useAlert(t('DEALS.FORM.MESSAGES.ERROR'));
  }
};

watch(() => pipelinesStore.records, openPipelineFallback);

watch(
  pipelineId,
  id => {
    if (id) savedViewsStore.fetch(id).catch(error => useAlert(error.message));
  },
  { immediate: true }
);

watch(
  () =>
    JSON.stringify([
      activeView.value?.id,
      activeView.value?.viewType,
      activeView.value?.filters,
      activeView.value?.sorts,
      stages.value.map(stage => stage.id),
      calendarRange.value,
    ]),
  fetchDeals,
  { immediate: true }
);

onMounted(() => {
  store.dispatch('agents/get');
  openPipelineFallback();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <div
      v-if="!pipelinesStore.records.length"
      class="flex items-center justify-center h-full text-sm text-n-slate-11"
    >
      <Spinner v-if="pipelinesStore.uiFlags.isFetching" />
      <span v-else>{{ t('DEALS.EMPTY_PIPELINES') }}</span>
    </div>
    <template v-else-if="pipeline">
      <header class="flex flex-col gap-3 px-6 pt-6 pb-3">
        <div class="flex items-center justify-between gap-2">
          <h1 class="text-xl font-medium truncate text-n-slate-12">
            {{ pipeline.name }}
          </h1>
          <Button
            :label="t('DEALS.TOOLBAR.NEW_DEAL')"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreateDeal()"
          />
        </div>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <ViewPicker
            :views="views"
            :active-view="activeView"
            :count="dealsStore.meta.count"
            @select="selectView"
            @create="openCreateView"
            @rename="openRenameView"
            @duplicate="duplicateView"
            @delete="openDeleteView"
          />
          <div v-if="activeView" class="flex items-center gap-1">
            <div class="relative">
              <Button
                id="toggleDealsFilterButton"
                :label="t('DEALS.TOOLBAR.FILTER')"
                icon="i-lucide-list-filter"
                color="slate"
                size="sm"
                variant="ghost"
                :class="{ 'bg-n-alpha-2': showFilters || hasActiveFilters }"
                @click="toggleFilters"
              />
              <div
                class="absolute z-40 mt-1 top-full ltr:right-0 rtl:left-0"
              >
                <DealsFilter
                  v-if="showFilters"
                  v-model="draftFilters"
                  :filter-types="filterTypes"
                  @apply="applyFilters"
                  @close="showFilters = false"
                />
              </div>
            </div>
            <DealsSortMenu
              :sorts="activeView.sorts"
              @update:sorts="updateActiveView({ sorts: $event })"
            />
            <div v-if="hasDealsAi" class="relative">
              <Button
                id="toggleDealsAiButton"
                :label="t('DEALS.AI.BUTTON')"
                icon="i-woot-tekomi"
                color="slate"
                size="sm"
                variant="ghost"
                :class="{ 'bg-n-alpha-2': showAiPanel }"
                @click="showAiPanel = !showAiPanel"
              />
              <div class="absolute z-40 mt-1 top-full ltr:right-0 rtl:left-0">
                <DealsAiPanel
                  v-if="showAiPanel"
                  :pipeline-id="pipelineId"
                  @close="showAiPanel = false"
                />
              </div>
            </div>
            <Button
              v-if="hasDealsAi"
              :label="t('DEALS.SUGGESTIONS.BUTTON')"
              icon="i-lucide-sparkles"
              color="slate"
              size="sm"
              variant="ghost"
              @click="dealSuggestionsDialogRef?.open()"
            />
            <DealsViewOptions :view="activeView" @update="updateActiveView" />
          </div>
        </div>
      </header>
      <main class="flex-1 min-h-0">
        <div
          v-if="!activeView"
          class="flex justify-center py-10 text-sm text-n-slate-11"
        >
          <Spinner v-if="savedViewsStore.uiFlags.isFetching" />
          <span v-else>{{ t('DEALS.VIEWS.EMPTY') }}</span>
        </div>
        <template v-else>
          <DealsKanbanView
            v-if="activeView.viewType === VIEW_TYPES.KANBAN"
            :deals="dealsStore.records"
            :stages="stages"
            :fields="activeFields"
            :stage-meta="dealsStore.stageMeta"
            :stage-stats="dealsStore.meta.stageStats"
            :settings="activeView.settings"
            :is-manual-order="isManualOrder"
            :is-fetching="dealsStore.uiFlags.isFetching"
            :fetching-stage-id="dealsStore.uiFlags.fetchingStageId"
            @move="moveDeal"
            @create="openCreateDeal"
            @load-more="loadMoreInStage"
            @open="openDeal"
          />
          <DealsTableView
            v-else-if="activeView.viewType === VIEW_TYPES.TABLE"
            :deals="dealsStore.records"
            :stages="stages"
            :agents="agents"
            :fields="tableFields"
            :group-by="activeView.groupBy"
            :has-more="dealsStore.meta.hasMore"
            :is-fetching="dealsStore.uiFlags.isFetching"
            :is-fetching-more="dealsStore.uiFlags.isFetchingMore"
            @update="updateDeal"
            @move="moveDeal"
            @delete="requestDeleteDeals"
            @load-more="loadMoreDeals"
            @update-fields="updateActiveView({ fields: $event })"
            @open="openDeal"
          />
          <DealsCalendarView
            v-else-if="activeView.viewType === VIEW_TYPES.CALENDAR"
            :key="activeView.id"
            :deals="dealsStore.records"
            :undated-deals="dealsStore.undatedRecords"
            :stages="stages"
            :fields="activeFields"
            :settings="activeView.settings"
            :is-fetching="dealsStore.uiFlags.isFetching"
            @range-change="calendarRange = $event"
            @update="updateDeal"
            @create="openCreateDeal"
            @open="openDeal"
          />
          <DealsListView
            v-else
            :deals="dealsStore.records"
            :stages="stages"
            :fields="activeFields"
            :group-by="activeView.groupBy"
            :has-more="dealsStore.meta.hasMore"
            :is-fetching="dealsStore.uiFlags.isFetching"
            :is-fetching-more="dealsStore.uiFlags.isFetchingMore"
            @load-more="loadMoreDeals"
            @open="openDeal"
          />
        </template>
      </main>
    </template>

    <SavedViewDialog
      ref="savedViewDialogRef"
      :is-loading="savedViewsStore.uiFlags.isSaving"
      @save="saveView"
    />
    <Dialog
      ref="deleteViewDialogRef"
      type="alert"
      :title="t('DEALS.VIEWS.DELETE_DIALOG.TITLE')"
      :description="
        t('DEALS.VIEWS.DELETE_DIALOG.DESCRIPTION', { name: editingView?.name })
      "
      :confirm-button-label="t('DEALS.VIEWS.DELETE_DIALOG.CONFIRM')"
      @confirm="deleteView"
    />
    <Dialog
      ref="deleteDealsDialogRef"
      type="alert"
      :title="t('DEALS.DELETE_DIALOG.TITLE')"
      :description="
        t(
          'DEALS.DELETE_DIALOG.DESCRIPTION',
          { count: pendingDeleteDeals.length },
          pendingDeleteDeals.length
        )
      "
      :confirm-button-label="t('DEALS.DELETE_DIALOG.CONFIRM')"
      @confirm="deleteDeals"
    />
    <SidePanel
      ref="dealPanelRef"
      :title="panelDeal?.name"
      width="2xl"
      @close="closeDealPanel"
    >
      <template #header-actions>
        <router-link
          v-if="panelDeal"
          :to="{ name: 'deals_show', params: { dealId: panelDeal.id } }"
        >
          <Button
            icon="i-lucide-maximize-2"
            color="slate"
            variant="ghost"
            size="sm"
          />
        </router-link>
      </template>
      <DealDetail
        v-if="panelDeal"
        :deal="panelDeal"
        @updated="dealsStore.watchDeal($event)"
        @delete="requestDeleteDeals([$event])"
      />
    </SidePanel>
    <DealSuggestionsDialog
      v-if="hasDealsAi"
      ref="dealSuggestionsDialogRef"
      :stages="stages"
    />
    <DealFormDialog
      ref="dealFormDialogRef"
      :stages="stages"
      :agents="agents"
      :is-loading="dealsStore.uiFlags.isCreating"
      @create="createDeal"
    />
  </section>
</template>
