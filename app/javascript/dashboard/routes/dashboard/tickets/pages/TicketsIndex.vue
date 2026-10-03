<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { vOnClickOutside } from '@vueuse/components';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import { useTicketViewsStore } from 'dashboard/stores/ticketViews';
import { useTicketsStore } from 'dashboard/stores/tickets';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TicketFormDialog from 'dashboard/components-next/Tickets/TicketFormDialog.vue';
import TicketsFilter from 'dashboard/components-next/Tickets/TicketsFilter.vue';
import TicketsSortMenu from 'dashboard/components-next/Tickets/TicketsSortMenu.vue';
import TicketViewDialog from 'dashboard/components-next/Tickets/TicketViewDialog.vue';
import TicketsViewOptions from 'dashboard/components-next/Tickets/TicketsViewOptions.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import TicketsKanbanView from 'dashboard/components-next/Tickets/views/TicketsKanbanView.vue';
import TicketsTableView from 'dashboard/components-next/Tickets/views/TicketsTableView.vue';
import { useTicketFields } from 'dashboard/components-next/Tickets/useTicketFields';
import { useTicketFilterTypes } from 'dashboard/components-next/Tickets/useTicketFilterTypes';
import {
  VIEW_TYPES,
  VIEW_TYPE_ICONS,
  visibleFields,
} from 'dashboard/components-next/Tickets/constants';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

const pipelinesStore = useTicketPipelinesStore();
const viewsStore = useTicketViewsStore();
const ticketsStore = useTicketsStore();
const agents = useMapGetter('agents/getAgents');
const { ticketAttributes } = useTicketFields();

const ticketFormDialogRef = ref(null);
const showFilters = ref(false);
const draftFilters = ref([]);
const viewDialogRef = ref(null);
const deleteViewDialogRef = ref(null);
const editingView = ref(null);
const showViewMenu = ref(false);

const pipelineId = computed(() => Number(route.params.pipelineId) || null);
const pipeline = computed(() =>
  pipelinesStore.getPipeline(pipelineId.value)
);
const stages = computed(() => pipeline.value?.stages || []);
const views = computed(() => viewsStore.records);
const activeView = computed(
  () => viewsStore.getView(route.query.viewId) || viewsStore.records[0]
);
const activeFields = computed(() =>
  visibleFields(activeView.value, ticketAttributes.value)
);
const isManualOrder = computed(() => !activeView.value?.sorts?.length);
const filterTypes = useTicketFilterTypes(stages);
const hasActiveFilters = computed(() => !!activeView.value?.filters?.length);
const isKanban = computed(
  () => (activeView.value?.viewType || VIEW_TYPES.KANBAN) === VIEW_TYPES.KANBAN
);

const alertError = error => useAlert(error.message);

const updateActiveView = attributes =>
  viewsStore.update(activeView.value.id, attributes).catch(alertError);

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
          attributeKey: 'title',
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

const applySorts = sorts => updateActiveView({ sorts });

const openCreateView = () => {
  editingView.value = null;
  viewDialogRef.value?.open();
};

const openRenameView = () => {
  editingView.value = activeView.value;
  viewDialogRef.value?.open(activeView.value);
};

const saveView = async ({ name, viewType }) => {
  try {
    if (editingView.value) {
      await viewsStore.update(editingView.value.id, { name });
    } else {
      const view = await viewsStore.create({
        name,
        viewType,
        pipelineId: pipelineId.value,
      });
      selectView(view.id);
    }
    viewDialogRef.value?.close();
  } catch {
    useAlert(t('TICKETS.VIEWS.MESSAGES.SAVE_ERROR'));
  }
};

const duplicateView = async () => {
  const view = activeView.value;
  try {
    const copy = await viewsStore.create({
      name: t('TICKETS.VIEWS.DUPLICATE_SUFFIX', { name: view.name }),
      viewType: view.viewType,
      pipelineId: view.pipelineId,
      filters: view.filters,
      sorts: view.sorts,
      fields: view.fields,
      settings: view.settings,
    });
    selectView(copy.id);
  } catch {
    useAlert(t('TICKETS.VIEWS.MESSAGES.SAVE_ERROR'));
  }
};

const deleteView = async () => {
  deleteViewDialogRef.value?.close();
  try {
    await viewsStore.delete(activeView.value.id);
    selectView(viewsStore.records[0]?.id);
    useAlert(t('TICKETS.VIEWS.MESSAGES.DELETE_SUCCESS'));
  } catch {
    useAlert(t('TICKETS.VIEWS.MESSAGES.DELETE_ERROR'));
  }
};

const viewMenuItems = computed(() => [
  { label: t('TICKETS.VIEWS.RENAME'), value: 'rename', action: 'rename' },
  { label: t('TICKETS.VIEWS.DUPLICATE'), value: 'duplicate', action: 'duplicate' },
  { label: t('TICKETS.VIEWS.DELETE'), value: 'delete', action: 'delete' },
]);

const onViewMenuAction = ({ action }) => {
  showViewMenu.value = false;
  if (action === 'rename') openRenameView();
  if (action === 'duplicate') duplicateView();
  if (action === 'delete') deleteViewDialogRef.value?.open();
};

const openPipelineFallback = () => {
  const [firstPipeline] = pipelinesStore.records;
  if (!pipeline.value && firstPipeline) {
    router.replace({
      name: 'tickets_pipeline_index',
      params: { pipelineId: firstPipeline.id },
    });
  }
};

const selectView = viewId => {
  router.replace({ query: { ...route.query, viewId } });
};

// The choice belongs to the view, so it sticks for everyone who opens it next.
const switchViewType = () => {
  const viewType = isKanban.value ? VIEW_TYPES.TABLE : VIEW_TYPES.KANBAN;
  updateActiveView({ viewType });
};

const fetchTickets = () => {
  const view = activeView.value;
  if (!view) return;
  const query = {
    pipelineId: pipelineId.value,
    filters: view.filters,
    sorts: view.sorts,
  };
  if (isKanban.value) {
    ticketsStore
      .fetchKanban(
        query,
        stages.value.map(stage => stage.id)
      )
      .catch(alertError);
    return;
  }
  ticketsStore.fetch(query).catch(alertError);
};

const loadMoreTickets = () => {
  ticketsStore.fetchMore().catch(alertError);
};

const loadMoreInStage = stageId => {
  ticketsStore.fetchMoreInStage(stageId).catch(alertError);
};

const moveTicket = ({ ticket, stageId, afterId, position }) => {
  const topPosition =
    Math.min(
      0,
      ...ticketsStore.records
        .filter(record => record.stageId === stageId)
        .map(record => record.position)
    ) - 1;
  ticketsStore
    .move(ticket, { stageId, afterId, position: position ?? topPosition })
    .catch(alertError);
};

const openTicket = ticket => {
  router.push({ name: 'tickets_show', params: { ticketId: ticket.id } });
};

const openCreateTicket = (defaults = {}) => {
  ticketFormDialogRef.value?.open(defaults);
};

const createTicket = async ticket => {
  try {
    await ticketsStore.create(ticket);
    ticketFormDialogRef.value?.close();
    useAlert(t('TICKETS.FORM.MESSAGES.SUCCESS'));
  } catch {
    useAlert(t('TICKETS.FORM.MESSAGES.ERROR'));
  }
};

watch(() => pipelinesStore.records, openPipelineFallback);

watch(
  pipelineId,
  id => {
    if (id) viewsStore.fetch(id).catch(alertError);
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
    ]),
  fetchTickets,
  { immediate: true }
);

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('attributes/get');
  pipelinesStore.fetch().then(openPipelineFallback).catch(alertError);
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <div
      v-if="!pipelinesStore.records.length"
      class="flex items-center justify-center h-full text-sm text-n-slate-11"
    >
      <Spinner v-if="pipelinesStore.uiFlags.isFetching" />
      <span v-else>{{ t('TICKETS.EMPTY_PIPELINES') }}</span>
    </div>
    <template v-else-if="pipeline">
      <header class="flex flex-col gap-3 px-6 pt-6 pb-3">
        <div class="flex items-center justify-between gap-2">
          <h1 class="text-xl font-medium truncate text-n-slate-12">
            {{ pipeline.name }}
          </h1>
          <Button
            :label="t('TICKETS.TOOLBAR.NEW_TICKET')"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreateTicket()"
          />
        </div>
        <div class="flex items-center gap-1 overflow-x-auto">
          <Button
            v-for="view in views"
            :key="view.id"
            :label="view.name"
            size="sm"
            variant="ghost"
            :color="view.id === activeView?.id ? 'blue' : 'slate'"
            @click="selectView(view.id)"
          />
          <Button
            v-tooltip.top="t('TICKETS.VIEWS.CREATE')"
            icon="i-lucide-plus"
            color="slate"
            variant="ghost"
            size="sm"
            @click="openCreateView"
          />
          <span class="ltr:ml-auto rtl:mr-auto text-sm text-n-slate-11">
            {{ t('TICKETS.COUNT', { n: ticketsStore.meta.count }) }}
          </span>
          <template v-if="activeView">
            <Button
              id="toggleTicketsFilterButton"
              :label="t('TICKETS.TOOLBAR.FILTER')"
              icon="i-lucide-list-filter"
              color="slate"
              variant="ghost"
              size="sm"
              :class="{ 'bg-n-alpha-2': showFilters || hasActiveFilters }"
              @click="toggleFilters"
            />
            <TicketsSortMenu
              :sorts="activeView.sorts || []"
              @update:sorts="applySorts"
            />
            <TicketsViewOptions
              :view="activeView"
              @update="updateActiveView"
            />
            <Button
              v-tooltip.top="
                isKanban ? t('TICKETS.VIEW.TABLE') : t('TICKETS.VIEW.KANBAN')
              "
              :icon="
                isKanban
                  ? VIEW_TYPE_ICONS[VIEW_TYPES.TABLE]
                  : VIEW_TYPE_ICONS[VIEW_TYPES.KANBAN]
              "
              color="slate"
              variant="ghost"
              size="sm"
              @click="switchViewType"
            />
            <div v-on-click-outside="() => (showViewMenu = false)" class="relative">
              <Button
                icon="i-lucide-ellipsis"
                color="slate"
                variant="ghost"
                size="sm"
                @click="showViewMenu = !showViewMenu"
              />
              <DropdownMenu
                v-if="showViewMenu"
                :menu-items="viewMenuItems"
                class="absolute z-40 ltr:right-0 rtl:left-0 top-full mt-1 w-40"
                @action="onViewMenuAction"
              />
            </div>
          </template>
        </div>
        <div v-if="showFilters" class="relative">
          <TicketsFilter
            v-model="draftFilters"
            class="absolute ltr:right-0 rtl:left-0 top-1"
            :filter-types="filterTypes"
            @apply="applyFilters"
            @close="showFilters = false"
          />
        </div>
      </header>

      <TicketsKanbanView
        v-if="isKanban"
        :tickets="ticketsStore.records"
        :stages="stages"
        :fields="activeFields"
        :stage-meta="ticketsStore.stageMeta"
        :stage-stats="ticketsStore.meta.stageStats"
        :settings="activeView?.settings || {}"
        :is-manual-order="isManualOrder"
        :is-fetching="ticketsStore.uiFlags.isFetching"
        :fetching-stage-id="ticketsStore.uiFlags.fetchingStageId"
        @move="moveTicket"
        @create="openCreateTicket"
        @load-more="loadMoreInStage"
        @open="openTicket"
      />

      <TicketsTableView
        v-else
        :tickets="ticketsStore.records"
        :stages="stages"
        :fields="activeFields"
        :has-more="ticketsStore.meta.hasMore"
        :is-fetching="ticketsStore.uiFlags.isFetching"
        :is-fetching-more="ticketsStore.uiFlags.isFetchingMore"
        @load-more="loadMoreTickets"
        @open="openTicket"
      />

      <TicketViewDialog
        ref="viewDialogRef"
        :is-loading="viewsStore.uiFlags.isSaving"
        @save="saveView"
      />

      <Dialog
        ref="deleteViewDialogRef"
        type="alert"
        :title="t('TICKETS.VIEWS.DELETE_CONFIRM.TITLE')"
        :description="
          t('TICKETS.VIEWS.DELETE_CONFIRM.DESCRIPTION', {
            name: activeView?.name,
          })
        "
        :confirm-button-label="t('TICKETS.VIEWS.DELETE_CONFIRM.CONFIRM')"
        @confirm="deleteView"
      />

      <TicketFormDialog
        ref="ticketFormDialogRef"
        :stages="stages"
        :agents="agents"
        :is-loading="ticketsStore.uiFlags.isCreating"
        @create="createTicket"
      />
    </template>
  </section>
</template>
