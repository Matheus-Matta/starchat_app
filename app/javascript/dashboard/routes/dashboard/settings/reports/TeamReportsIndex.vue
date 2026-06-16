<script setup>
import { ref } from 'vue';
import ReportHeader from './components/ReportHeader.vue';
import SummaryReports from './components/SummaryReports.vue';
import DownloadReportButton from './components/DownloadReportButton.vue';

const summarReportsRef = ref(null);

const onDownloadClick = format => {
  summarReportsRef.value.downloadReports(format);
};
</script>

<template>
  <ReportHeader
    :header-title="$t('TEAM_REPORTS.HEADER')"
    :header-description="$t('TEAM_REPORTS.DESCRIPTION')"
  >
    <DownloadReportButton
      :label="$t('TEAM_REPORTS.DOWNLOAD_TEAM_REPORTS')"
      @download="onDownloadClick"
    />
  </ReportHeader>

  <SummaryReports
    ref="summarReportsRef"
    action-key="summaryReports/fetchTeamSummaryReports"
    getter-key="teams/getTeams"
    fetch-items-key="teams/get"
    summary-key="summaryReports/getTeamSummaryReports"
    type="team"
  />
</template>
