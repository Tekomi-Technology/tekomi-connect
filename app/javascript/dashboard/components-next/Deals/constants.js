import { format, fromUnixTime, parseISO } from 'date-fns';

export const VIEW_TYPES = {
  TABLE: 'table',
  KANBAN: 'kanban',
  CALENDAR: 'calendar',
  LIST: 'list',
};

export const VIEW_TYPE_ICONS = {
  [VIEW_TYPES.TABLE]: 'i-lucide-table',
  [VIEW_TYPES.KANBAN]: 'i-lucide-square-kanban',
  [VIEW_TYPES.CALENDAR]: 'i-lucide-calendar-days',
  [VIEW_TYPES.LIST]: 'i-lucide-list',
};

export const DEAL_FIELDS = [
  'value',
  'stage',
  'assignee',
  'contact',
  'expected_close_date',
  'created_at',
];

export const SORT_FIELDS = [
  'name',
  'value',
  'expected_close_date',
  'created_at',
  'updated_at',
];

export const GROUP_BY_FIELDS = ['stage', 'assignee'];

export const AGGREGATES = ['count', 'sum', 'avg', 'min', 'max'];

export const CALENDAR_FIELDS = ['expected_close_date', 'closed_at', 'created_at'];

export const CALENDAR_MODES = ['month', 'week', 'day'];

export const DEFAULT_COLUMN_WIDTH = 160;

const vndFormatter = new Intl.NumberFormat('vi-VN', {
  style: 'currency',
  currency: 'VND',
  maximumFractionDigits: 0,
});

export const formatVND = value =>
  value === null || value === undefined ? '' : vndFormatter.format(value);

export const CUSTOM_FIELD_PREFIX = 'custom_attributes.';

export const customAttributeKey = field =>
  field.startsWith(CUSTOM_FIELD_PREFIX)
    ? field.slice(CUSTOM_FIELD_PREFIX.length)
    : null;

export const normalizeFields = (view, attributes = []) => {
  const fieldKeys = [
    ...DEAL_FIELDS,
    ...attributes.map(
      attribute => `${CUSTOM_FIELD_PREFIX}${attribute.attributeKey}`
    ),
  ];
  const saved = (view?.fields || []).filter(field =>
    fieldKeys.includes(field.key)
  );
  const savedKeys = saved.map(field => field.key);
  return [
    ...saved,
    ...fieldKeys
      .filter(key => !savedKeys.includes(key))
      .map(key => ({ key, visible: !view?.fields?.length })),
  ];
};

export const visibleFields = (view, attributes = []) =>
  normalizeFields(view, attributes)
    .filter(field => field.visible)
    .map(field => field.key);

export const toDate = value =>
  typeof value === 'number' ? fromUnixTime(value) : parseISO(value);

export const formatDealDate = value =>
  value ? format(toDate(value), 'dd/MM/yyyy') : '';

export const positionBetween = (previous, next) => {
  if (previous === undefined && next === undefined) return 0;
  if (previous === undefined) return next - 1;
  if (next === undefined) return previous + 1;
  return (previous + next) / 2;
};
