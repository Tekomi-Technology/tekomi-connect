<script setup>
import SummaryReports from './components/SummaryReports.vue';
</script>

<template>
  <SummaryReports
    action-key="summaryReports/fetchLabelSummaryReports"
    getter-key="labels/getLabels"
    fetch-items-key="labels/get"
    summary-key="summaryReports/getLabelSummaryReports"
    type="label"
    :header-title="$t('LABEL_REPORTS.HEADER')"
    :header-description="$t('LABEL_REPORTS.DESCRIPTION')"
    :download-label="$t('LABEL_REPORTS.DOWNLOAD_LABEL_REPORTS')"
  />
</template>
