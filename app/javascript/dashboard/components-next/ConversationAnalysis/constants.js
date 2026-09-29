export const QUALITY_CRITERIA = [
  'understanding',
  'completeness',
  'accuracy',
  'tone',
  'resolution',
  'proactiveness',
];

export const PROFILE_FIELDS = [
  { section: 'customer', prefix: 'CUSTOMER', key: 'budget' },
  { section: 'customer', prefix: 'CUSTOMER', key: 'timeline' },
  { section: 'customer', prefix: 'CUSTOMER', key: 'products_of_interest' },
  { section: 'customer', prefix: 'CUSTOMER', key: 'needs' },
  { section: 'customer', prefix: 'CUSTOMER', key: 'current_solution' },
  { section: 'insight', prefix: 'INSIGHT', key: 'pain_points' },
  { section: 'insight', prefix: 'INSIGHT', key: 'barriers' },
  { section: 'insight', prefix: 'INSIGHT', key: 'motivations' },
];

export const INTEREST_BADGE_CLASSES = {
  high: 'bg-n-teal-3 text-n-teal-11',
  medium: 'bg-n-amber-3 text-n-amber-11',
  low: 'bg-n-slate-3 text-n-slate-11',
  unknown: 'bg-n-slate-3 text-n-slate-10',
};

export const SENTIMENT_BADGE_CLASSES = {
  positive: 'bg-n-teal-3 text-n-teal-11',
  neutral: 'bg-n-slate-3 text-n-slate-11',
  concerned: 'bg-n-amber-3 text-n-amber-11',
  frustrated: 'bg-n-ruby-3 text-n-ruby-11',
  unknown: 'bg-n-slate-3 text-n-slate-10',
};

export const toList = value => {
  if (Array.isArray(value)) return value.filter(Boolean);
  return value ? [value] : [];
};

export const hasValue = value => toList(value).length > 0;

export const scoreTextClass = score => {
  if (score === null || score === undefined) return 'text-n-slate-10';
  if (score >= 80) return 'text-n-teal-11';
  if (score >= 60) return 'text-n-amber-11';
  return 'text-n-ruby-11';
};

export const scoreVerdict = score => {
  if (score >= 80) return 'GOOD';
  if (score >= 60) return 'FAIR';
  return 'POOR';
};

export const criterionBarClass = score => {
  if (score >= 4) return 'bg-n-teal-9';
  if (score === 3) return 'bg-n-amber-9';
  return 'bg-n-ruby-9';
};
