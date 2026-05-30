<script>
import { useAlert, useTrack } from 'dashboard/composables';
import ReportFilterSelector from './components/FilterSelector.vue';
import { GROUP_BY_FILTER } from './constants';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import ReportContainer from './ReportContainer.vue';
import ReportHeader from './components/ReportHeader.vue';

const STATUS_REPORTS_KEYS = {
  STATUS_OPEN: 'status_open_count',
  STATUS_RESOLVED: 'status_resolved_count',
  STATUS_SNOOZED: 'status_snoozed_count',
  STATUS_PENDING: 'status_pending_count',
};

export default {
  name: 'StatusReports',
  components: {
    ReportHeader,
    ReportFilterSelector,
    ReportContainer,
  },
  data() {
    return {
      from: 0,
      to: 0,
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
    };
  },
  computed: {
    reportKeys() {
      return STATUS_REPORTS_KEYS;
    },
  },
  methods: {
    fetchAllData() {
      this.fetchAccountSummary();
      this.fetchChartData();
    },
    fetchAccountSummary() {
      try {
        this.$store.dispatch('fetchAccountSummary', this.getRequestPayload());
      } catch {
        useAlert(this.$t('REPORT.SUMMARY_FETCHING_FAILED'));
      }
    },
    fetchChartData() {
      Object.keys(STATUS_REPORTS_KEYS).forEach(async key => {
        try {
          await this.$store.dispatch('fetchAccountReport', {
            metric: STATUS_REPORTS_KEYS[key],
            ...this.getRequestPayload(),
          });
        } catch {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        }
      });
    },
    getRequestPayload() {
      const { from, to, groupBy, businessHours } = this;

      return {
        from,
        to,
        groupBy: groupBy?.period,
        businessHours,
      };
    },
    onFilterChange({ from, to, groupBy, businessHours }) {
      this.from = from;
      this.to = to;
      this.groupBy = groupBy;
      this.businessHours = businessHours;
      this.fetchAllData();

      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterValue: { from, to, groupBy, businessHours },
        reportType: 'status_reports',
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4 pb-6">
    <ReportHeader :header-title="$t('REPORT.STATUS_REPORTS_HEADER')" />
    <ReportFilterSelector
      :show-agents-filter="false"
      show-group-by-filter
      @filter-change="onFilterChange"
    />
    <ReportContainer :group-by="groupBy" :report-keys="reportKeys" />
  </div>
</template>
