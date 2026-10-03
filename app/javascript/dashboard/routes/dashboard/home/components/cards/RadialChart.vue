<script setup>
import { computed } from 'vue';
import VueApexCharts from 'vue3-apexcharts';
import { useChartTheme } from '../../composables/useChartTheme';

// One-value radial: a full ring or (`gauge`) a half-circle gauge.
const props = defineProps({
  value: { type: Number, default: null },
  label: { type: String, default: '' },
  gauge: { type: Boolean, default: false },
  color: { type: String, default: '' },
  height: { type: Number, default: 220 },
});

const { baseOptions, colors } = useChartTheme();

const options = computed(() => {
  const base = baseOptions.value;
  const angle = props.gauge ? 110 : 360;
  return {
    chart: { ...base.chart, type: 'radialBar', sparkline: { enabled: true } },
    theme: base.theme,
    colors: [props.color || colors.value.brand],
    fill: {
      type: 'gradient',
      gradient: {
        shade: colors.value.mode,
        type: 'horizontal',
        gradientToColors: [colors.value.palette[5]],
        stops: [0, 100],
      },
    },
    stroke: { lineCap: 'round' },
    plotOptions: {
      radialBar: {
        startAngle: props.gauge ? -angle : 0,
        endAngle: angle,
        hollow: { size: props.gauge ? '62%' : '68%' },
        track: { background: colors.value.track, strokeWidth: '100%' },
        dataLabels: {
          name: {
            show: Boolean(props.label),
            offsetY: props.gauge ? 24 : 22,
            color: colors.value.text,
            fontSize: '12px',
          },
          value: {
            offsetY: props.gauge ? -14 : -12,
            color: colors.value.strong,
            fontSize: '30px',
            fontWeight: 700,
            formatter: value => (props.value == null ? '—' : `${value}%`),
          },
        },
      },
    },
    labels: [props.label],
  };
});
</script>

<template>
  <VueApexCharts
    type="radialBar"
    :height="height"
    :options="options"
    :series="[value ?? 0]"
  />
</template>
