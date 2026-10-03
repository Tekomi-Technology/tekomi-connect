<script setup>
import SummaryReports from './components/SummaryReports.vue';
</script>

<template>
  <SummaryReports
    action-key="summaryReports/fetchAgentSummaryReports"
    getter-key="agents/getAgents"
    fetch-items-key="agents/get"
    summary-key="summaryReports/getAgentSummaryReports"
    type="agent"
    :header-title="$t('AGENT_REPORTS.HEADER')"
    :header-description="$t('AGENT_REPORTS.DESCRIPTION')"
    :download-label="$t('AGENT_REPORTS.DOWNLOAD_AGENT_REPORTS')"
  />
</template>
