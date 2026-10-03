import { computed, ref } from 'vue';
import { useMutationObserver, usePreferredReducedMotion } from '@vueuse/core';

// Theme tokens are `R G B` triplets on <body> (`.dark` swaps them).
const readColor = name => {
  const value = getComputedStyle(document.body)
    .getPropertyValue(`--${name}`)
    .trim();
  return `rgb(${value.split(/\s+/).join(', ')})`;
};

export function useChartTheme() {
  const isDark = ref(document.body.classList.contains('dark'));
  useMutationObserver(
    document.body,
    () => {
      isDark.value = document.body.classList.contains('dark');
    },
    { attributes: true, attributeFilter: ['class'] }
  );
  const reducedMotion = usePreferredReducedMotion();

  const colors = computed(() => {
    // Re-read the tokens whenever the theme flips.
    const mode = isDark.value ? 'dark' : 'light';
    return {
      mode,
      palette: [
        readColor('teal-9'),
        readColor('violet-9'),
        readColor('amber-9'),
        readColor('ruby-9'),
        readColor('slate-9'),
        readColor('teal-11'),
      ],
      brand: readColor('teal-9'),
      ruby: readColor('ruby-9'),
      amber: readColor('amber-9'),
      track: readColor('slate-4'),
      text: readColor('slate-11'),
      strong: readColor('slate-12'),
      grid: readColor('slate-5'),
    };
  });

  const baseOptions = computed(() => ({
    chart: {
      fontFamily: 'inherit',
      background: 'transparent',
      toolbar: { show: false },
      zoom: { enabled: false },
      animations: {
        enabled: reducedMotion.value !== 'reduce',
        speed: 700,
        animateGradually: { enabled: true, delay: 80 },
        dynamicAnimation: { enabled: true, speed: 450 },
      },
    },
    theme: { mode: colors.value.mode },
    colors: colors.value.palette,
    dataLabels: { enabled: false },
    legend: { show: false },
    grid: {
      borderColor: colors.value.grid,
      strokeDashArray: 4,
      padding: { left: 8, right: 8 },
    },
    tooltip: { theme: colors.value.mode },
    xaxis: {
      labels: { style: { colors: colors.value.text, fontSize: '11px' } },
      axisBorder: { show: false },
      axisTicks: { show: false },
    },
    yaxis: {
      labels: { style: { colors: colors.value.text, fontSize: '11px' } },
    },
  }));

  return { colors, baseOptions };
}
