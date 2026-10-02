<script setup>
import { computed } from 'vue';
import VueApexCharts from 'vue3-apexcharts';
import { useChartTheme } from '../../composables/useChartTheme';

const props = defineProps({
  // [{ name, data: [{ timestamp, value }] }] — all series share timestamps.
  series: { type: Array, required: true },
  type: { type: String, default: 'area' },
  groupBy: { type: String, default: 'day' },
  height: { type: Number, default: 280 },
  stacked: { type: Boolean, default: false },
  colors: { type: Array, default: null },
  formatValue: { type: Function, default: value => Math.round(value) },
});

const { baseOptions } = useChartTheme();

const labelFormat = computed(
  () =>
    new Intl.DateTimeFormat(
      undefined,
      props.groupBy === 'hour'
        ? { hour: '2-digit', minute: '2-digit' }
        : { day: '2-digit', month: '2-digit' }
    )
);

const categories = computed(() =>
  (props.series[0]?.data ?? []).map(point =>
    labelFormat.value.format(new Date(point.timestamp * 1000))
  )
);

const chartSeries = computed(() =>
  props.series.map(item => ({
    name: item.name,
    data: item.data.map(point => Number(point.value) || 0),
  }))
);

const options = computed(() => {
  const base = baseOptions.value;
  return {
    ...base,
    chart: { ...base.chart, type: props.type, stacked: props.stacked },
    ...(props.colors && { colors: props.colors }),
    stroke: {
      curve: 'smooth',
      width: props.type === 'bar' ? 0 : 3,
    },
    fill:
      props.type === 'area'
        ? {
            type: 'gradient',
            gradient: { opacityFrom: 0.35, opacityTo: 0.02, stops: [0, 95] },
          }
        : { opacity: 1 },
    plotOptions: {
      bar: {
        borderRadius: 6,
        columnWidth: '55%',
        borderRadiusApplication: 'end',
      },
    },
    markers: { size: 0, hover: { size: 5 } },
    xaxis: {
      ...base.xaxis,
      categories: categories.value,
      tickAmount: Math.min(categories.value.length, 8),
      labels: { ...base.xaxis.labels, rotate: 0, hideOverlappingLabels: true },
    },
    yaxis: {
      ...base.yaxis,
      labels: { ...base.yaxis.labels, formatter: props.formatValue },
    },
    tooltip: { ...base.tooltip, y: { formatter: props.formatValue } },
  };
});
</script>

<template>
  <VueApexCharts
    :type="type"
    :height="height"
    :options="options"
    :series="chartSeries"
  />
</template>
