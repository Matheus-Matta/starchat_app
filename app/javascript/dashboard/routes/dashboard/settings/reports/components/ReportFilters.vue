<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import differenceInDays from 'date-fns/differenceInDays';
import ActiveFilterChip from './Filters/v3/ActiveFilterChip.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { GROUP_BY_FILTER } from '../constants';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import {
  generateReportURLParams,
  parseReportURLParams,
  parseCompareIdsParam,
  generateCompareIdsParam,
} from '../helpers/reportFilterHelper';

const props = defineProps({
  filterType: {
    type: String,
    required: false,
    default: '',
    validator: value =>
      ['teams', 'inboxes', 'labels', 'agents', ''].includes(value),
  },
  selectedItem: {
    type: Object,
    default: null,
  },
  showGroupBy: {
    type: Boolean,
    default: true,
  },
  showBusinessHours: {
    type: Boolean,
    default: true,
  },
  showEntityFilter: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['filterChange']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const buildReportFilterList = (items, type) => {
  if (!Array.isArray(items)) return [];

  return items.map(item => ({
    id: item.id,
    name: item.name || item.title,
    type,
  }));
};

const showGroupByDropdown = ref(false);
const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const businessHoursSelected = ref(false);
const groupBy = ref(GROUP_BY_FILTER[1]);
const groupByfilterItemsList = ref([{ id: 1, name: 'Day' }]);

// Extra entities (besides `selectedItem`, the page's anchor entity) selected to
// combine/sum metrics for, e.g. comparing Agent X's page with Agent Y's data too.
const compareIds = ref([]);

const filterSource = computed(() => {
  const sources = {
    teams: store.getters['teams/getTeams'],
    inboxes: store.getters['inboxes/getInboxes'],
    labels: store.getters['labels/getLabels'],
    agents: store.getters['agents/getAgents'],
  };
  return sources[props.filterType] || [];
});

const from = computed(() => getUnixStartOfDay(customDateRange.value[0]));
const to = computed(() => getUnixEndOfDay(customDateRange.value[1]));

const daysDifference = computed(() => {
  return differenceInDays(customDateRange.value[1], customDateRange.value[0]);
});

const isGroupByPossible = computed(() => {
  return props.showGroupBy && daysDifference.value >= 29;
});

const GROUP_BY_OPTIONS = computed(() => ({
  WEEK: [
    { id: 1, name: t('REPORT.GROUPING_OPTIONS.DAY') },
    { id: 2, name: t('REPORT.GROUPING_OPTIONS.WEEK') },
  ],
  MONTH: [
    { id: 1, name: t('REPORT.GROUPING_OPTIONS.DAY') },
    { id: 2, name: t('REPORT.GROUPING_OPTIONS.WEEK') },
    { id: 3, name: t('REPORT.GROUPING_OPTIONS.MONTH') },
  ],
  YEAR: [
    { id: 2, name: t('REPORT.GROUPING_OPTIONS.WEEK') },
    { id: 3, name: t('REPORT.GROUPING_OPTIONS.MONTH') },
    { id: 4, name: t('REPORT.GROUPING_OPTIONS.YEAR') },
  ],
}));

const fetchFilterItems = () => {
  const days = daysDifference.value;
  if (days >= 364) return GROUP_BY_OPTIONS.value.YEAR;
  if (days >= 90) return GROUP_BY_OPTIONS.value.MONTH;
  if (days >= 29) return GROUP_BY_OPTIONS.value.WEEK;
  return GROUP_BY_OPTIONS.value.WEEK;
};

const filterOptions = computed(() =>
  buildReportFilterList(filterSource.value, props.filterType).map(item => ({
    value: item.id,
    label: item.name,
  }))
);

// The anchor entity (whose page we're on) is always included and locked
// (via :disabled-values) so it can't be unchecked from this combobox.
const anchorIds = computed(() =>
  props.selectedItem?.id ? [props.selectedItem.id] : []
);

const comparePlaceholder = computed(() => {
  const placeholders = {
    teams: 'TEAM_REPORTS.FILTERS.COMPARE_PLACEHOLDER',
    inboxes: 'INBOX_REPORTS.FILTERS.COMPARE_PLACEHOLDER',
    labels: 'LABEL_REPORTS.FILTERS.COMPARE_PLACEHOLDER',
    agents: 'AGENT_REPORTS.FILTERS.COMPARE_PLACEHOLDER',
  };
  return t(placeholders[props.filterType] || '');
});

// v-model bridge between ComboBox's flat id array (anchor + compares) and the
// `compareIds` ref that's persisted to the URL and sent to the API.
const comboModel = computed({
  get: () => [...anchorIds.value, ...compareIds.value],
  set: values => {
    compareIds.value = values.filter(id => !anchorIds.value.includes(id));
    updateURLParams();
    emitChange();
  },
});

const updateURLParams = () => {
  const params = generateReportURLParams({
    from: from.value,
    to: to.value,
    businessHours: businessHoursSelected.value,
    groupBy: isGroupByPossible.value ? groupBy.value.id : null,
    range: selectedDateRange.value,
  });

  router.replace({
    query: { ...params, ...generateCompareIdsParam(compareIds.value) },
  });
};

const emitChange = () => {
  const payload = {
    from: from.value,
    to: to.value,
    businessHours: businessHoursSelected.value,
  };

  if (props.showGroupBy) {
    // Always emit groupBy, default to day when range is too short
    payload.groupBy = isGroupByPossible.value
      ? groupBy.value
      : GROUP_BY_FILTER[1];
  }

  if (props.showEntityFilter) {
    const ids = [props.selectedItem?.id, ...compareIds.value].filter(Boolean);

    if (ids.length) {
      payload[props.filterType] = ids.map(id => ({ id }));
    }
  }

  updateURLParams();
  emit('filterChange', payload);
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  groupByfilterItemsList.value = fetchFilterItems();
  const filterItems = groupByfilterItemsList.value.filter(
    item => item.id === groupBy.value.id
  );
  if (filterItems.length === 0) {
    groupBy.value = GROUP_BY_FILTER[groupByfilterItemsList.value[0].id];
  }
  emitChange();
};

const onBusinessHoursToggle = () => {
  emitChange();
};

const onGroupByFilterChange = payload => {
  groupBy.value = GROUP_BY_FILTER[payload.id];
  showGroupByDropdown.value = false;
  emitChange();
};

const toggleGroupByDropdown = () => {
  showGroupByDropdown.value = !showGroupByDropdown.value;
};

const closeGroupByDropdown = () => {
  showGroupByDropdown.value = false;
};

const initializeFromURL = () => {
  const urlParams = parseReportURLParams(route.query);

  // Set the range type first
  if (urlParams.range) {
    selectedDateRange.value = urlParams.range;
  }

  // Restore dates from URL if available
  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }

  if (urlParams.businessHours) {
    businessHoursSelected.value = urlParams.businessHours;
  }

  if (urlParams.groupBy) {
    const groupByValue = GROUP_BY_FILTER[urlParams.groupBy];
    if (groupByValue) {
      groupBy.value = groupByValue;
    }
  }

  // Restore the extra compared entities (the anchor entity itself comes from
  // `selectedItem`, driven by the route param)
  if (props.showEntityFilter) {
    compareIds.value = parseCompareIdsParam(route.query).filter(
      id => id !== props.selectedItem?.id
    );
  }
};

onMounted(() => {
  initializeFromURL();
  groupByfilterItemsList.value = fetchFilterItems();
  emitChange();
});
</script>

<template>
  <div class="flex flex-col w-full gap-3 lg:flex-row">
    <WootDatePicker
      v-model:date-range="customDateRange"
      v-model:range-type="selectedDateRange"
      @date-range-changed="onDateRangeChange"
    />

    <div class="flex gap-2 items-center w-full">
      <ComboBox
        v-if="showEntityFilter && filterOptions.length"
        v-model="comboModel"
        class="!w-48 [&>div>button]:h-8"
        :options="filterOptions"
        :disabled-values="anchorIds"
        :placeholder="comparePlaceholder"
        multiple
      />

      <ActiveFilterChip
        v-if="isGroupByPossible"
        :id="groupBy?.id"
        :name="
          groupByfilterItemsList.find(item => item.id === groupBy?.id)?.name ||
          $t('REPORT.GROUP_BY_FILTER_DROPDOWN_LABEL')
        "
        type="groupBy"
        :options="groupByfilterItemsList"
        :active-filter-type="showGroupByDropdown ? 'groupBy' : ''"
        :show-menu="showGroupByDropdown"
        :placeholder="$t('REPORT.GROUP_BY_FILTER_DROPDOWN_LABEL')"
        :enable-search="false"
        :show-clear-filter="false"
        @toggle-dropdown="toggleGroupByDropdown"
        @close-dropdown="closeGroupByDropdown"
        @add-filter="onGroupByFilterChange"
        @remove-filter="() => {}"
      />

      <div
        v-if="showBusinessHours"
        class="flex items-center flex-shrink-0 ltr:ml-auto rtl:mr-auto"
      >
        <span class="mx-2 text-sm whitespace-nowrap">
          {{ $t('REPORT.BUSINESS_HOURS') }}
        </span>
        <span>
          <ToggleSwitch
            v-model="businessHoursSelected"
            @change="onBusinessHoursToggle"
          />
        </span>
      </div>
    </div>
  </div>
</template>
