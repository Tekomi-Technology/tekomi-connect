<script setup>
import { computed } from 'vue';
import VueApexCharts from 'vue3-apexcharts';
import { useChartTheme } from '../../composables/useChartTheme';

const props = defineProps({
  categories: { type: Array, required: true },
  values: { type: Array, required: true },
  name: { type: String, default: '' },
  horizontal: { type: Boolean, default: false },
  colors: { type: Array, default: null },
  height: { type: Number, default: 260 },
});

const { baseOptions } = useChartTheme();

const options = computed(() => {
  const base = baseOptions.value;
  return {
    ...base,
    chart: { ...base.chart, type: 'bar' },
    ...(props.colors && { colors: props.colors }),
    plotOptions: {
      bar: {
        horizontal: props.horizontal,
        distributed: Boolean(props.colors),
        borderRadius: 6,
        borderRadiusApplication: 'end',
        barHeight: '60%',
        columnWidth: '50%',
      },
    },
    dataLabels: {
      enabled: true,
      style: { fontSize: '11px', fontWeight: 600 },
    },
    xaxis: { ...base.xaxis, categories: props.categories },
    yaxis: base.yaxis,
  };
});

const series = computed(() => [{ name: props.name, data: props.values }]);
</script>

<template>
  <VueApexCharts
    type="bar"
    :height="height"
    :options="options"
    :series="series"
  />
</template>
