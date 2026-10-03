<script setup>
import SummaryReports from './components/SummaryReports.vue';
</script>

<template>
  <SummaryReports
    action-key="summaryReports/fetchTeamSummaryReports"
    getter-key="teams/getTeams"
    fetch-items-key="teams/get"
    summary-key="summaryReports/getTeamSummaryReports"
    type="team"
    :header-title="$t('TEAM_REPORTS.HEADER')"
    :header-description="$t('TEAM_REPORTS.DESCRIPTION')"
    :download-label="$t('TEAM_REPORTS.DOWNLOAD_TEAM_REPORTS')"
  />
</template>
