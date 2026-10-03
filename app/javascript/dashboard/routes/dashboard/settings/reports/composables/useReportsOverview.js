import { computed, ref, shallowRef, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import ReportsAPI from 'dashboard/api/reports';
import { periodRange } from 'dashboard/routes/dashboard/home/helpers';

export function useReportsOverview() {
  const store = useStore();

  const period = ref('month');
  const dimension = ref('inbox');
  const range = ref(periodRange(period.value));

  const statusData = shallowRef(null);
  const isLoading = ref(false);
  const hasError = ref(false);

  const summary = useMapGetter('getAccountSummary');
  const slaMetrics = useMapGetter('slaReports/getMetrics');
  const inboxRows = useMapGetter('summaryReports/getInboxSummaryReports');
  const agentRows = useMapGetter('summaryReports/getAgentSummaryReports');
  const inboxes = useMapGetter('inboxes/getInboxes');
  const agents = useMapGetter('agents/getAgents');

  let requestId = 0;
  const load = async () => {
    requestId += 1;
    const currentRequest = requestId;
    range.value = periodRange(period.value);
    isLoading.value = true;
    hasError.value = false;

    const { since, until, groupBy } = range.value;

    try {
      const [statusResponse] = await Promise.all([
        ReportsAPI.getConversationStatus({
          from: since,
          to: until,
          groupBy,
          dimension: dimension.value,
        }),
        store.dispatch('fetchAccountSummary', {
          from: since,
          to: until,
          groupBy,
        }),
        store.dispatch('slaReports/getMetrics', { from: since, to: until }),
        store.dispatch('summaryReports/fetchInboxSummaryReports', {
          since,
          until,
        }),
        store.dispatch('summaryReports/fetchAgentSummaryReports', {
          since,
          until,
        }),
      ]);
      // A slower response for an older filter must not overwrite a newer one.
      if (currentRequest !== requestId) return;
      statusData.value = statusResponse.data;
    } catch {
      if (currentRequest === requestId) hasError.value = true;
    } finally {
      if (currentRequest === requestId) isLoading.value = false;
    }
  };

  watch([period, dimension], load);

  const named = (rows, source, fallbackName) =>
    rows.value.map(row => ({
      ...row,
      name: source.value.find(item => item.id === row.id)?.name || fallbackName,
    }));

  const inboxSummary = computed(() => named(inboxRows, inboxes, ''));
  const agentSummary = computed(() => named(agentRows, agents, ''));

  return {
    period,
    dimension,
    range,
    summary,
    slaMetrics,
    inboxSummary,
    agentSummary,
    statusData,
    isLoading,
    hasError,
    load,
  };
}
