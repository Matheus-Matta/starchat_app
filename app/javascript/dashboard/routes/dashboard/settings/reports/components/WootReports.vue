<script>
import { useAlert } from 'dashboard/composables';
import ReportFilters from './ReportFilters.vue';
import ReportContainer from '../ReportContainer.vue';
import DownloadReportButton from './DownloadReportButton.vue';
import { GROUP_BY_FILTER } from '../constants';
import { generateFileName } from '../../../../../helper/downloadHelper';
import ReportHeader from './ReportHeader.vue';

export default {
  components: {
    ReportHeader,
    DownloadReportButton,
    ReportFilters,
    ReportContainer,
  },
  props: {
    type: {
      type: String,
      default: 'account',
    },
    getterKey: {
      type: String,
      default: '',
    },
    actionKey: {
      type: String,
      default: '',
    },
    downloadButtonLabel: {
      type: String,
      default: 'Download Reports',
    },
    reportTitle: {
      type: String,
      default: 'Download Reports',
    },
    hasBackButton: {
      type: Boolean,
      default: false,
    },
    selectedItem: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      from: 0,
      to: 0,
      selectedFilter: this.selectedItem,
      selectedIds: this.selectedItem ? [this.selectedItem.id] : [],
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
    };
  },
  computed: {
    filterType() {
      const pluralMap = {
        agent: 'agents',
        team: 'teams',
        inbox: 'inboxes',
        label: 'labels',
      };
      return pluralMap[this.type] || this.type;
    },
    filterItemsList() {
      return this.$store.getters[this.getterKey] || [];
    },
    isAgentType() {
      return this.type === 'agent';
    },
    reportKeys() {
      return {
        CONVERSATIONS: 'conversations_count',
        ATTENDANCES: 'attendances_count',
        ...(!this.isAgentType && {
          INCOMING_MESSAGES: 'incoming_messages_count',
        }),
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
      };
    },
  },
  mounted() {
    this.$store.dispatch(this.actionKey);
  },
  methods: {
    fetchAllData() {
      if (this.selectedFilter) {
        const { from, to, groupBy, businessHours } = this;
        this.$store.dispatch('fetchAccountSummary', {
          from,
          to,
          type: this.type,
          id: this.selectedIds,
          groupBy: groupBy.period,
          businessHours,
        });
        this.fetchChartData();
      }
    },
    fetchChartData() {
      Object.keys(this.reportKeys).forEach(async key => {
        try {
          const { from, to, groupBy, businessHours } = this;
          this.$store.dispatch('fetchAccountReport', {
            metric: this.reportKeys[key],
            from,
            to,
            type: this.type,
            id: this.selectedIds,
            groupBy: groupBy.period,
            businessHours,
          });
        } catch {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        }
      });
    },
    downloadReports(format = 'csv') {
      const { from, to, type, businessHours, selectedItem } = this;

      // The agent detail page downloads one row per conversation handled by this
      // agent (not the account-wide per-day summary used by the agents list page),
      // so it needs its own action/endpoint.
      if (type === 'agent' && selectedItem?.id) {
        const fileName = generateFileName({
          type: 'agent_conversations',
          to,
          businessHours,
        });
        this.$store.dispatch('downloadAgentConversationsReport', {
          agentId: selectedItem.id,
          from,
          to,
          fileName,
          businessHours,
          format,
        });
        return;
      }

      const dispatchMethods = {
        label: 'downloadLabelReports',
        inbox: 'downloadInboxReports',
        team: 'downloadTeamReports',
      };
      if (dispatchMethods[type]) {
        const fileName = generateFileName({ type, to, businessHours });
        const params = { from, to, fileName, businessHours, format };
        this.$store.dispatch(dispatchMethods[type], params);
      }
    },
    onFilterChange(payload) {
      const { from, to, businessHours, groupBy } = payload;
      this.from = from;
      this.to = to;
      this.businessHours = businessHours;

      if (groupBy) {
        this.groupBy = groupBy;
      } else {
        this.groupBy = GROUP_BY_FILTER[1];
      }

      // Get filter value directly from filterType key (anchor entity + any
      // entities selected for comparison, combined into a single series)
      const filterValue = payload[this.filterType];
      if (filterValue) {
        const items = Array.isArray(filterValue) ? filterValue : [filterValue];
        this.selectedFilter = items[0];
        this.selectedIds = items.map(item => item.id);
      } else {
        this.selectedFilter = null;
        this.selectedIds = [];
      }

      this.fetchAllData();
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="reportTitle" :has-back-button="hasBackButton">
    <DownloadReportButton
      :label="downloadButtonLabel"
      @download="downloadReports"
    />
  </ReportHeader>

  <ReportFilters
    v-if="filterItemsList"
    :filter-type="filterType"
    :selected-item="selectedFilter"
    @filter-change="onFilterChange"
  />
  <ReportContainer
    v-if="filterItemsList.length"
    :group-by="groupBy"
    :report-keys="reportKeys"
  />
</template>
