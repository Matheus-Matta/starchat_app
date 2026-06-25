<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import DownloadReportButton from './components/DownloadReportButton.vue';
import ReportHeader from './components/ReportHeader.vue';
import ReportContainer from './ReportContainer.vue';
import CsatMetricCard from './components/CsatMetricCard.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { GROUP_BY_FILTER } from './constants';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { useReportMetrics } from 'dashboard/composables/useReportMetrics';
import { STATUS } from 'dashboard/store/constants';
import subDays from 'date-fns/subDays';
import differenceInDays from 'date-fns/differenceInDays';

const store = useStore();
const { t } = useI18n();

// Headline numbers for the conversations matching the current filters,
// complementing the historical charts below with an at-a-glance summary.
const { displayMetric, fetchingStatus } = useReportMetrics();
const isSummaryLoading = computed(
  () => fetchingStatus.value === STATUS.FETCHING
);
const summaryMetrics = computed(() => [
  {
    key: 'conversations_count',
    label: t('SUMMARY_REPORTS.CONVERSATIONS'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.CONVERSATIONS'),
  },
  {
    key: 'avg_first_response_time',
    label: t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.AVG_FIRST_RESPONSE_TIME'),
  },
  {
    key: 'avg_resolution_time',
    label: t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.AVG_RESOLUTION_TIME'),
  },
  {
    key: 'reply_time',
    label: t('SUMMARY_REPORTS.AVG_REPLY_TIME'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.AVG_REPLY_TIME'),
  },
  {
    key: 'resolutions_count',
    label: t('SUMMARY_REPORTS.RESOLUTION_COUNT'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.RESOLUTION_COUNT'),
  },
  {
    key: 'no_first_reply_count',
    label: t('SUMMARY_REPORTS.NO_FIRST_REPLY'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.NO_FIRST_REPLY'),
  },
  {
    key: 'waiting_count',
    label: t('SUMMARY_REPORTS.WAITING'),
    tooltip: t('SUMMARY_REPORTS.TOOLTIPS.WAITING'),
  },
]);

// Date range
const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const groupBy = ref(GROUP_BY_FILTER[1]);
const businessHours = ref(false);

// Dimension filters - teams, agents and inboxes can be combined together
// (e.g. Agent A + Team B): their conversations/metrics are combined with OR
// into a single series, not summed as if they were the same type.
const selectedTeamIds = ref([]);
const selectedAgentIds = ref([]);
const selectedInboxIds = ref([]);
const selectedStatus = ref(null);

const from = computed(() => getUnixStartOfDay(customDateRange.value[0]));
const to = computed(() => getUnixEndOfDay(customDateRange.value[1]));

const daysDifference = computed(() =>
  differenceInDays(customDateRange.value[1], customDateRange.value[0])
);

const isGroupByPossible = computed(() => daysDifference.value >= 29);

// Store data
const allTeams = useMapGetter('teams/getTeams');
const allAgents = useMapGetter('agents/getAgents');
const allInboxes = useMapGetter('inboxes/getInboxes');

// Select options
const teamOptions = computed(() =>
  (allTeams.value || []).map(team => ({ value: team.id, label: team.name }))
);
const agentOptions = computed(() =>
  (allAgents.value || []).map(a => ({ value: a.id, label: a.name }))
);
const inboxOptions = computed(() =>
  (allInboxes.value || []).map(i => ({ value: i.id, label: i.name }))
);
const statusOptions = computed(() => [
  { value: null, label: t('REPORT.FILTERS.ALL_STATUSES') },
  { value: 'open', label: t('REPORT.FILTERS.STATUS_OPEN') },
  { value: 'resolved', label: t('REPORT.FILTERS.STATUS_RESOLVED') },
  { value: 'pending', label: t('REPORT.FILTERS.STATUS_PENDING') },
  { value: 'snoozed', label: t('REPORT.FILTERS.STATUS_SNOOZED') },
]);

const statusLabel = computed(
  () =>
    statusOptions.value.find(o => o.value === selectedStatus.value)?.label ||
    t('REPORT.FILTERS.ALL_STATUSES')
);

const onTeamChange = ids => {
  selectedTeamIds.value = ids;
  fetchAllData();
};
const onAgentChange = ids => {
  selectedAgentIds.value = ids;
  fetchAllData();
};
const onInboxChange = ids => {
  selectedInboxIds.value = ids;
  fetchAllData();
};
const onStatusChange = v => {
  selectedStatus.value = v;
  fetchAllData();
};

const getRequestPayload = () => ({
  from: from.value,
  to: to.value,
  groupBy: isGroupByPossible.value
    ? groupBy.value?.period
    : GROUP_BY_FILTER[1].period,
  businessHours: businessHours.value,
  type: 'account',
  agentIds: selectedAgentIds.value,
  teamIds: selectedTeamIds.value,
  inboxIds: selectedInboxIds.value,
  status: selectedStatus.value,
});

const fetchChartData = () => {
  const REPORT_KEYS = [
    'conversations_count',
    'unique_contacts_count',
    'status_open_count',
    'status_resolved_count',
    'status_snoozed_count',
    'status_pending_count',
    'attendances_count',
    'incoming_messages_count',
    'outgoing_messages_count',
    'avg_first_response_time',
    'avg_resolution_time',
    'resolutions_count',
    'reply_time',
  ];
  REPORT_KEYS.forEach(async metric => {
    try {
      await store.dispatch('fetchAccountReport', {
        metric,
        ...getRequestPayload(),
      });
    } catch {
      useAlert(t('REPORT.DATA_FETCHING_FAILED'));
    }
  });
};

const fetchAccountSummary = async () => {
  try {
    await store.dispatch('fetchAccountSummary', getRequestPayload());
  } catch {
    useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
  }
};

const fetchAllData = () => {
  fetchAccountSummary();
  fetchChartData();
};

const onDateRangeChange = ([startDate, endDate, rangeType]) => {
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  fetchAllData();
};

const onBusinessHoursToggle = () => fetchAllData();

const downloadConversationReports = (format = 'csv') => {
  const fileName = generateFileName({
    type: 'conversation',
    to: to.value,
    businessHours: businessHours.value,
  });
  store.dispatch('downloadConversationsSummaryReports', {
    from: from.value,
    to: to.value,
    fileName,
    businessHours: businessHours.value,
    format,
  });
};

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  store.dispatch('inboxes/get');
  fetchAllData();
});
</script>

<template>
  <ReportHeader :header-title="$t('REPORT.HEADER')">
    <DownloadReportButton
      :label="$t('REPORT.DOWNLOAD_CONVERSATION_REPORTS')"
      @download="downloadConversationReports"
    />
  </ReportHeader>

  <div
    class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-4 py-4 lg:px-5 mt-4"
  >
    <div class="flex flex-col gap-4">
      <WootDatePicker
        v-model:date-range="customDateRange"
        v-model:range-type="selectedDateRange"
        @date-range-changed="onDateRangeChange"
      />

      <div class="flex flex-wrap items-end gap-x-6 gap-y-4">
        <!-- Dimension group -->
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-semibold uppercase text-n-slate-11">
            {{ $t('REPORT.FILTERS.DIMENSION_LABEL') }}
          </span>
          <div class="flex flex-wrap gap-2">
            <ComboBox
              :model-value="selectedTeamIds"
              :options="teamOptions"
              class="!w-48 [&>div>button]:h-8"
              multiple
              :placeholder="$t('REPORT.FILTERS.ALL_TEAMS')"
              @update:model-value="onTeamChange"
            />
            <ComboBox
              :model-value="selectedAgentIds"
              :options="agentOptions"
              class="!w-48 [&>div>button]:h-8"
              multiple
              :placeholder="$t('REPORT.FILTERS.ALL_AGENTS')"
              @update:model-value="onAgentChange"
            />
            <ComboBox
              :model-value="selectedInboxIds"
              :options="inboxOptions"
              class="!w-48 [&>div>button]:h-8"
              multiple
              :placeholder="$t('REPORT.FILTERS.ALL_INBOXES')"
              @update:model-value="onInboxChange"
            />
          </div>
        </div>

        <div class="hidden md:block h-8 w-px self-end bg-n-weak" />

        <!-- Status + business hours group -->
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-semibold uppercase text-n-slate-11">
            {{ $t('REPORT.FILTERS.STATUS_LABEL') }}
          </span>
          <div class="flex flex-wrap items-center gap-3">
            <SelectMenu
              sub-menu-position="bottom"
              :options="statusOptions"
              :label="statusLabel"
              :model-value="selectedStatus"
              @update:model-value="onStatusChange"
            />
            <div class="flex items-center gap-2 text-sm text-n-slate-11">
              <span class="whitespace-nowrap">
                {{ $t('REPORT.BUSINESS_HOURS') }}
              </span>
              <ToggleSwitch
                v-model="businessHours"
                @change="onBusinessHoursToggle"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div
    class="flex flex-wrap gap-x-6 gap-y-4 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5 mt-4"
  >
    <template v-for="(metric, index) in summaryMetrics" :key="metric.key">
      <div v-if="index > 0" class="hidden sm:block w-px bg-n-strong" />
      <CsatMetricCard
        :label="metric.label"
        :tooltip="metric.tooltip"
        :value="displayMetric(metric.key)"
        :is-loading="isSummaryLoading"
      />
    </template>
  </div>

  <ReportContainer :group-by="groupBy" />
</template>
