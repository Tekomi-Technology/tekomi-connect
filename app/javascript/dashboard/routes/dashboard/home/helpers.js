import { INBOX_TYPES } from 'dashboard/helper/inbox';

const HOUR = 60 * 60;
const DAY = 24 * HOUR;

export const PERIODS = ['day', 'week', 'month', 'quarter'];

// `since`/`until` in epoch seconds plus the bucket size for the charts.
export const periodRange = (period, now = new Date()) => {
  const until = Math.floor(now.getTime() / 1000);
  if (period === 'quarter') {
    const quarterStart = new Date(
      now.getFullYear(),
      Math.floor(now.getMonth() / 3) * 3,
      1
    );
    return {
      since: Math.floor(quarterStart.getTime() / 1000),
      until,
      groupBy: 'week',
    };
  }
  const span = { day: DAY, week: 7 * DAY, month: 30 * DAY }[period];
  return {
    since: until - span,
    until,
    groupBy: period === 'day' ? 'hour' : 'day',
  };
};

export const percent = (part, total) =>
  total ? Math.round((part / total) * 100) : 0;

// Signed change vs the previous period, `null` when there is nothing to compare.
export const deltaPercent = (current, previous) => {
  if (current == null || !previous) return null;
  return Math.round(((current - previous) / previous) * 100);
};

export const formatNumber = value =>
  value == null ? '—' : new Intl.NumberFormat().format(value);

// Seconds -> { value, unit } so templates can style the unit separately.
export const splitDuration = seconds => {
  if (seconds == null) return { value: '—', unit: '' };
  if (seconds < 60) return { value: Math.round(seconds), unit: 'SECONDS' };
  if (seconds < HOUR)
    return { value: Math.round(seconds / 60), unit: 'MINUTES' };
  if (seconds < DAY) {
    return { value: Math.round((seconds / HOUR) * 10) / 10, unit: 'HOURS' };
  }
  return { value: Math.round((seconds / DAY) * 10) / 10, unit: 'DAYS' };
};

const CHANNEL_KEYS = {
  [INBOX_TYPES.WEB]: 'WEB',
  [INBOX_TYPES.FB]: 'FACEBOOK',
  [INBOX_TYPES.INSTAGRAM]: 'INSTAGRAM',
  [INBOX_TYPES.TIKTOK]: 'TIKTOK',
  [INBOX_TYPES.WHATSAPP]: 'WHATSAPP',
  [INBOX_TYPES.TWILIO]: 'SMS',
  [INBOX_TYPES.SMS]: 'SMS',
  [INBOX_TYPES.EMAIL]: 'EMAIL',
  [INBOX_TYPES.TELEGRAM]: 'TELEGRAM',
  [INBOX_TYPES.LINE]: 'LINE',
  [INBOX_TYPES.API]: 'API',
  [INBOX_TYPES.ZALO_OA]: 'ZALO_OA',
  [INBOX_TYPES.ZALO_PERSONAL]: 'ZALO_PERSONAL',
  [INBOX_TYPES.PHONE]: 'PHONE',
};

export const channelLabelKey = channelType =>
  `HOME.DASHBOARD.CHANNELS.${CHANNEL_KEYS[channelType] || 'OTHER'}`;

// Tailwind classes per palette slot; order matches `useChartTheme` palette.
export const SERIES_DOT_CLASSES = [
  'bg-n-brand',
  'bg-n-violet-9',
  'bg-n-amber-9',
  'bg-n-ruby-9',
  'bg-n-slate-9',
  'bg-n-teal-11',
];

export const formatDuration = (seconds, t) => {
  const { value, unit } = splitDuration(seconds);
  return unit ? `${value} ${t(`HOME.DASHBOARD.UNITS.${unit}`)}` : value;
};
