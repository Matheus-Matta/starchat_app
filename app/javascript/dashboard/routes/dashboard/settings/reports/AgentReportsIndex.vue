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
    :header-title="$t('AGENT_REPORTS.HEADER')"
    :header-description="$t('AGENT_REPORTS.DESCRIPTION')"
  >
    <DownloadReportButton
      :label="$t('AGENT_REPORTS.DOWNLOAD_AGENT_REPORTS')"
      @download="onDownloadClick"
    />
  </ReportHeader>

  <SummaryReports
    ref="summarReportsRef"
    action-key="summaryReports/fetchAgentSummaryReports"
    getter-key="agents/getAgents"
    fetch-items-key="agents/get"
    summary-key="summaryReports/getAgentSummaryReports"
    type="agent"
  />
</template>
