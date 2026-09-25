export const QUALITY_CRITERIA = [
  'understanding',
  'completeness',
  'accuracy',
  'tone',
  'resolution',
  'proactiveness',
];

export const CUSTOMER_FIELDS = [
  'needs',
  'products_of_interest',
  'current_solution',
  'budget',
  'timeline',
];

export const INSIGHT_FIELDS = ['pain_points', 'barriers', 'motivations'];

export const STATE_FIELDS = ['already_done', 'open_questions'];

export const CARE_FIELDS = [
  'next_action',
  'talking_points',
  'opportunity',
  'contact_timing',
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

export const scoreTextClass = score => {
  if (score === null || score === undefined) return 'text-n-slate-10';
  if (score >= 80) return 'text-n-teal-11';
  if (score >= 60) return 'text-n-amber-11';
  return 'text-n-ruby-11';
};
