import { describe, expect, it } from 'vitest';

import {
  EMOTION_CONFIG,
  normalizedEmotionTag,
  normalizeEmotion,
} from './emotionUtils';

describe('emotionUtils', () => {
  it.each([
    ['vui', 'vui'],
    ['Vui vẻ', 'vui'],
    ['positive', 'vui'],
    ['trung tính', 'trung tính'],
    ['TRUNG TINH', 'trung tính'],
    ['trung', 'trung tính'],
    ['neutral', 'trung tính'],
    ['buồn', 'buồn'],
    ['BUON', 'buồn'],
    ['sad', 'buồn'],
    ['khó', 'khó chịu'],
    ['chịu', 'khó chịu'],
    ['Khó chịu', 'khó chịu'],
    ['kho chiu', 'khó chịu'],
    ['frustrated', 'khó chịu'],
    ['annoyed', 'khó chịu'],
    ['gay gắt', 'gay gắt'],
    ['gay', 'gay gắt'],
    ['gắt', 'gay gắt'],
    ['GAY GAT', 'gay gắt'],
    ['angry', 'gay gắt'],
  ])('normalizes %s to %s', (input, expected) => {
    expect(normalizeEmotion(input)).toBe(expected);
  });

  it('gives every canonical emotion a distinct color', () => {
    const colors = Object.values(EMOTION_CONFIG).map(({ color }) => color);

    expect(new Set(colors).size).toBe(Object.keys(EMOTION_CONFIG).length);
  });

  it('corrects a stale short label and stale color together', () => {
    expect(normalizedEmotionTag({ label: 'khó', color: 'green' })).toEqual({
      label: 'khó chịu',
      color: 'orange',
    });
  });
});
