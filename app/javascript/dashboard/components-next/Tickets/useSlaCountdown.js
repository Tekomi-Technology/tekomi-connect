import { computed } from 'vue';
import { useTimestamp } from '@vueuse/core';
import { SLA_STATUSES, SLA_STATUS_STYLES } from './constants';

const MINUTE = 60;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const formatDuration = seconds => {
  if (seconds >= DAY) {
    const days = Math.floor(seconds / DAY);
    const hours = Math.floor((seconds % DAY) / HOUR);
    return hours ? `${days}d ${hours}h` : `${days}d`;
  }
  if (seconds >= HOUR) {
    const hours = Math.floor(seconds / HOUR);
    const minutes = Math.floor((seconds % HOUR) / MINUTE);
    return minutes ? `${hours}h ${minutes}m` : `${hours}h`;
  }
  return `${Math.max(Math.floor(seconds / MINUTE), 0)}m`;
};

/**
 * Live countdown to the deadline of the stage a ticket currently sits in.
 * Ticks once a minute, which is the same cadence the server evaluates SLAs at.
 */
export function useSlaCountdown(ticket) {
  const now = useTimestamp({ interval: MINUTE * 1000 });

  const sla = computed(() => ticket.value?.sla ?? null);

  const status = computed(() => sla.value?.slaStatus ?? SLA_STATUSES.NO_SLA);

  const hasSla = computed(() => status.value !== SLA_STATUSES.NO_SLA);

  const remainingSeconds = computed(() => {
    if (!sla.value?.dueAt) return null;
    return sla.value.dueAt - Math.floor(now.value / 1000);
  });

  const isOverdue = computed(() => (remainingSeconds.value ?? 0) < 0);

  const label = computed(() => {
    if (remainingSeconds.value === null) return '';
    return formatDuration(Math.abs(remainingSeconds.value));
  });

  const style = computed(() => SLA_STATUS_STYLES[status.value] ?? null);

  return { sla, status, hasSla, remainingSeconds, isOverdue, label, style };
}
