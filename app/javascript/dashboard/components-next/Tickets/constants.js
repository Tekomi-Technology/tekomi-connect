import { format, fromUnixTime, parseISO } from 'date-fns';

// Tickets offer a board and a table; the calendar and list types the saved view
// table also supports belong to deals.
export const VIEW_TYPES = {
  TABLE: 'table',
  KANBAN: 'kanban',
};

export const VIEW_TYPE_ICONS = {
  [VIEW_TYPES.TABLE]: 'i-lucide-table',
  [VIEW_TYPES.KANBAN]: 'i-lucide-square-kanban',
};

export const TICKET_FIELDS = [
  'sla',
  'stage',
  'assignee',
  'contact',
  'created_by',
  'created_at',
];

export const SORT_FIELDS = ['title', 'sla_status', 'created_at', 'updated_at'];

export const SLA_STATUSES = {
  ON_TRACK: 'on_track',
  AT_RISK: 'at_risk',
  BREACHED: 'breached',
  NO_SLA: 'no_sla',
};

export const SLA_STATUS_STYLES = {
  [SLA_STATUSES.AT_RISK]: {
    card: 'border-n-amber-8',
    text: 'text-n-amber-11',
    icon: 'i-lucide-clock-alert',
  },
  [SLA_STATUSES.BREACHED]: {
    card: 'border-n-ruby-8',
    text: 'text-n-ruby-11',
    icon: 'i-lucide-circle-alert',
  },
};

export const CREATED_BY_ICONS = {
  staff: 'i-lucide-user-round',
  ai_chatbot: 'i-lucide-message-circle',
  ai_callbot: 'i-lucide-phone',
  webhook: 'i-lucide-webhook',
};

export const DEFAULT_COLUMN_WIDTH = 160;

export const CUSTOM_FIELD_PREFIX = 'custom_attributes.';

export const customAttributeKey = field =>
  field.startsWith(CUSTOM_FIELD_PREFIX)
    ? field.slice(CUSTOM_FIELD_PREFIX.length)
    : null;

export const normalizeFields = (view, attributes = []) => {
  const fieldKeys = [
    ...TICKET_FIELDS,
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

export const formatTicketDate = value =>
  value ? format(toDate(value), 'dd/MM/yyyy HH:mm') : '';

export const positionBetween = (previous, next) => {
  if (previous === undefined && next === undefined) return 0;
  if (previous === undefined) return next - 1;
  if (next === undefined) return previous + 1;
  return (previous + next) / 2;
};
