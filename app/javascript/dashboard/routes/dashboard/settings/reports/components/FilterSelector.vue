<script setup>
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { GROUP_BY_FILTER } from '../constants';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import {
  generateReportURLParams,
  parseReportURLParams,
} from '../helpers/reportFilterHelper';

defineProps({
  showAgentsFilter: {
    type: Boolean,
    default: true,
  },
  showGroupByFilter: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['filterChange']);

const route = useRoute();
const router = useRouter();

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const businessHoursSelected = ref(false);
const selectedGroupBy = ref(GROUP_BY_FILTER[1]);

const updateURLParams = () => {
  const params = generateReportURLParams({
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    groupBy: selectedGroupBy.value?.period,
    businessHours: businessHoursSelected.value,
  });

  router.push({
    name: route.name,
    query: { ...route.query, ...params },
  });
};

const handleDateRangeChange = range => {
  if (range.length >= 2) {
    customDateRange.value = [range[0], range[1]];
    if (range[2]) selectedDateRange.value = range[2];
    emitFilterChange();
  }
};

const handleBusinessHoursChange = () => {
  emitFilterChange();
};

const handleGroupByChange = groupBy => {
  selectedGroupBy.value = groupBy;
  emitFilterChange();
};

const emitFilterChange = () => {
  updateURLParams();

  emit('filterChange', {
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    groupBy: selectedGroupBy.value,
    businessHours: businessHoursSelected.value,
  });
};

onMounted(() => {
  const parsedParams = parseReportURLParams(route.query);

  if (parsedParams.from && parsedParams.to) {
    customDateRange.value = [
      new Date(parsedParams.from * 1000),
      new Date(parsedParams.to * 1000),
    ];
  }

  if (parsedParams.businessHours) {
    businessHoursSelected.value = parsedParams.businessHours;
  }

  if (parsedParams.groupBy) {
    selectedGroupBy.value = GROUP_BY_FILTER.find(
      filter => filter.period === parsedParams.groupBy
    );
  }
});
</script>

<template>
  <div class="report-filter-selector">
    <div
      class="flex flex-col gap-4 rounded-xl bg-n-solid-2 p-4 outline outline-1 outline-n-container shadow-sm lg:p-5"
    >
      <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-end">
        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('REPORT.DATE_RANGE') }}
          </label>
          <WootDatePicker
            v-model:date-range="customDateRange"
            v-model:range-type="selectedDateRange"
            @date-range-changed="handleDateRangeChange"
          />
        </div>

        <div
          class="flex min-h-10 items-center justify-between gap-3 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
        >
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('REPORT.BUSINESS_HOURS') }}
          </label>
          <ToggleSwitch
            v-model="businessHoursSelected"
            @change="handleBusinessHoursChange"
          />
        </div>
      </div>

      <div v-if="showGroupByFilter" class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('REPORT.GROUP_BY') }}
        </label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="groupBy in GROUP_BY_FILTER"
            :key="groupBy.period"
            type="button"
            class="h-8 rounded-md px-3 text-sm font-medium transition-colors outline outline-1"
            :class="[
              selectedGroupBy?.period === groupBy.period
                ? 'bg-n-brand text-white outline-n-brand'
                : 'bg-n-solid-1 text-n-slate-11 outline-n-container hover:bg-n-alpha-2 hover:text-n-slate-12',
            ]"
            @click="handleGroupByChange(groupBy)"
          >
            {{ groupBy.label }}
          </button>
        </div>
      </div>

      <div class="flex flex-wrap gap-2 text-xs text-n-slate-11">
        <span class="rounded-md bg-n-alpha-2 px-2 py-1">
          {{ $t('REPORT.DATE_RANGE') }}
          <span class="font-medium text-n-slate-12">
            {{ selectedDateRange }}
          </span>
        </span>
        <span
          v-if="showGroupByFilter && selectedGroupBy"
          class="rounded-md bg-n-alpha-2 px-2 py-1"
        >
          {{ $t('REPORT.GROUP_BY') }}
          <span class="font-medium text-n-slate-12">{{
            selectedGroupBy.label
          }}</span>
        </span>
        <span
          v-if="businessHoursSelected"
          class="rounded-md bg-n-alpha-2 px-2 py-1 font-medium text-n-slate-12"
        >
          {{ $t('REPORT.BUSINESS_HOURS') }}
        </span>
      </div>
    </div>
  </div>
</template>
