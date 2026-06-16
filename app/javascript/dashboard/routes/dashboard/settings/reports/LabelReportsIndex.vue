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
    :header-title="$t('LABEL_REPORTS.HEADER')"
    :header-description="$t('LABEL_REPORTS.DESCRIPTION')"
  >
    <DownloadReportButton
      :label="$t('LABEL_REPORTS.DOWNLOAD_LABEL_REPORTS')"
      @download="onDownloadClick"
    />
  </ReportHeader>

  <SummaryReports
    ref="summarReportsRef"
    action-key="summaryReports/fetchLabelSummaryReports"
    getter-key="labels/getLabels"
    fetch-items-key="labels/get"
    summary-key="summaryReports/getLabelSummaryReports"
    type="label"
  />
</template>
