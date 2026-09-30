export const EMOTION_CONFIG = {
  vui: { color: 'blue', aliases: ['vui ve', 'tich cuc', 'happy', 'positive'] },
  'trung tính': {
    color: 'green',
    aliases: ['trung', 'trung tinh', 'neutral'],
  },
  buồn: { color: 'purple', aliases: ['buon', 'sad', 'tieu cuc'] },
  'khó chịu': {
    color: 'orange',
    aliases: [
      'kho',
      'chiu',
      'kho chiu',
      'khong hai long',
      'buc boi',
      'frustrated',
      'dissatisfied',
      'annoyed',
    ],
  },
  'gay gắt': {
    color: 'red',
    aliases: ['gay', 'gat', 'gay gat', 'tuc gian', 'angry', 'aggressive'],
  },
};

const comparableLabel = value =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');

export const normalizeEmotion = value => {
  if (!value) return '';

  const label = value.toString().normalize('NFKC').toLowerCase().trim();
  const comparable = comparableLabel(label);
  const match = Object.entries(EMOTION_CONFIG).find(
    ([canonical, config]) =>
      comparableLabel(canonical) === comparable ||
      config.aliases.includes(comparable)
  );

  return match?.[0] || label;
};

export const normalizedEmotionTag = tag => {
  if (!tag?.label) return null;

  const label = normalizeEmotion(tag.label);
  return {
    label,
    color: EMOTION_CONFIG[label]?.color || 'gray',
  };
};
