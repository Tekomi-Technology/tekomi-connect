import { computed, ref, shallowRef, watch } from 'vue';
import DashboardAPI from 'dashboard/api/dashboard';
import { periodRange } from '../helpers';

const timezoneOffset = () => -new Date().getTimezoneOffset() / 60;

export function useOverviewDashboard() {
  const period = ref('week');
  const inboxId = ref('');
  const data = shallowRef(null);
  const isLoading = ref(false);
  const hasError = ref(false);
  const updatedAt = ref(null);
  const range = ref(periodRange(period.value));

  let requestId = 0;
  const load = async () => {
    requestId += 1;
    const currentRequest = requestId;
    range.value = periodRange(period.value);
    isLoading.value = true;
    hasError.value = false;
    try {
      const { since, until, groupBy } = range.value;
      const response = await DashboardAPI.get({
        since,
        until,
        group_by: groupBy,
        inbox_id: inboxId.value || undefined,
        timezone_offset: timezoneOffset(),
      });
      // A slower response for an older filter must not overwrite a newer one.
      if (currentRequest !== requestId) return;
      data.value = response.data;
      updatedAt.value = Date.now();
    } catch {
      if (currentRequest === requestId) hasError.value = true;
    } finally {
      if (currentRequest === requestId) isLoading.value = false;
    }
  };

  watch([period, inboxId], load);

  const days = computed(() =>
    Math.max(1, Math.round((range.value.until - range.value.since) / 86400))
  );

  return {
    period,
    inboxId,
    data,
    range,
    days,
    isLoading,
    hasError,
    updatedAt,
    load,
  };
}
