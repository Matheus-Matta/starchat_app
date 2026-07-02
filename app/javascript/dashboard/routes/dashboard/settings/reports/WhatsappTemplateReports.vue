<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { subDays } from 'date-fns';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import ReportHeader from './components/ReportHeader.vue';

const store = useStore();

const customDateRange = ref([subDays(new Date(), 29), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_30_DAYS);
const selectedInboxId = ref('');
const templateFilter = ref('');

const whatsappInboxes = computed(() =>
  store.getters['inboxes/getInboxes'].filter(
    i => i.channel_type === 'Channel::Whatsapp'
  )
);

const records = computed(
  () => store.getters['whatsappTemplateReports/getRecords']
);
const isFetching = computed(
  () => store.getters['whatsappTemplateReports/isFetching']
);

const inboxOptions = computed(() =>
  whatsappInboxes.value.map(inbox => ({ value: inbox.id, label: inbox.name }))
);

const templateOptions = computed(() => {
  const names = [...new Set(records.value.map(r => r.template_name))].sort();
  return [
    { value: '', label: '' },
    ...names.map(n => ({ value: n, label: n })),
  ];
});

const filteredRecords = computed(() => {
  if (!templateFilter.value) return records.value;
  return records.value.filter(r => r.template_name === templateFilter.value);
});

const totals = computed(() =>
  filteredRecords.value.reduce(
    (acc, r) => {
      acc.total += r.total;
      acc.sent += r.sent;
      acc.delivered += r.delivered;
      acc.read += r.read;
      acc.failed += r.failed;
      return acc;
    },
    { total: 0, sent: 0, delivered: 0, read: 0, failed: 0 }
  )
);

const rate = (numerator, denominator) =>
  denominator > 0 ? `${((numerator / denominator) * 100).toFixed(1)}%` : '—';

const fetchData = () => {
  if (!selectedInboxId.value) return;
  store.dispatch('whatsappTemplateReports/get', {
    inboxId: selectedInboxId.value,
    since: getUnixStartOfDay(customDateRange.value[0]),
    until: getUnixEndOfDay(customDateRange.value[1]),
  });
};

const onDateRangeChange = ([start, end, rangeType]) => {
  customDateRange.value = [start, end];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  fetchData();
};

const onInboxChange = value => {
  selectedInboxId.value = value;
  templateFilter.value = '';
  fetchData();
};

watch(whatsappInboxes, inboxes => {
  if (inboxes.length && !selectedInboxId.value) {
    selectedInboxId.value = inboxes[0].id;
    fetchData();
  }
});

onMounted(() => {
  store.dispatch('inboxes/get');
});
</script>

<template>
  <ReportHeader :header-title="$t('WHATSAPP_TEMPLATE_REPORTS.HEADER')" />

  <div class="flex flex-col gap-6">
    <!-- Filtros -->
    <div
      class="flex flex-col flex-wrap w-full gap-3 md:flex-row md:items-center"
    >
      <WootDatePicker
        v-model:date-range="customDateRange"
        v-model:range-type="selectedDateRange"
        @date-range-changed="onDateRangeChange"
      />
      <ComboBox
        :model-value="selectedInboxId"
        :options="inboxOptions"
        class="!w-56 [&>div>button]:h-8"
        :placeholder="$t('WHATSAPP_TEMPLATE_REPORTS.FILTERS.INBOX_PLACEHOLDER')"
        @update:model-value="onInboxChange"
      />
      <ComboBox
        v-model="templateFilter"
        :options="templateOptions"
        class="!w-56 [&>div>button]:h-8"
        :placeholder="
          $t('WHATSAPP_TEMPLATE_REPORTS.FILTERS.TEMPLATE_PLACEHOLDER')
        "
      />
    </div>

    <!-- Tabela -->
    <div
      class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 overflow-hidden"
    >
      <!-- Carregando -->
      <div
        v-if="isFetching"
        class="flex items-center justify-center gap-2 py-16 text-n-slate-10 text-sm"
      >
        <span class="i-lucide-loader-2 animate-spin text-lg" />
        {{ $t('WHATSAPP_TEMPLATE_REPORTS.LOADING') }}
      </div>

      <!-- Sem inbox -->
      <div
        v-else-if="!selectedInboxId"
        class="flex flex-col items-center justify-center gap-2 py-16 text-n-slate-10"
      >
        <span class="i-lucide-inbox text-4xl" />
        <p class="text-sm">
          {{ $t('WHATSAPP_TEMPLATE_REPORTS.SELECT_INBOX_PROMPT') }}
        </p>
      </div>

      <!-- Sem dados -->
      <div
        v-else-if="!filteredRecords.length"
        class="flex flex-col items-center justify-center gap-1 py-16 text-n-slate-10"
      >
        <span class="i-lucide-bar-chart-2 text-4xl" />
        <p class="text-sm font-medium text-n-slate-12">
          {{ $t('WHATSAPP_TEMPLATE_REPORTS.NO_DATA') }}
        </p>
        <p class="text-sm">
          {{ $t('WHATSAPP_TEMPLATE_REPORTS.NO_DATA_DESCRIPTION') }}
        </p>
      </div>

      <!-- Tabela com dados -->
      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-n-solid-2 border-b border-n-container">
            <tr>
              <th
                class="text-left py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.TEMPLATE') }}
              </th>
              <th
                class="text-left py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.LANGUAGE') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.TOTAL') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.SENT') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.DELIVERED') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.READ') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.FAILED') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.DELIVERY_RATE') }}
              </th>
              <th
                class="text-right py-3 px-5 font-medium text-sm text-n-slate-12"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.READ_RATE') }}
              </th>
            </tr>
          </thead>

          <tbody class="divide-y divide-n-container">
            <tr
              v-for="row in filteredRecords"
              :key="`${row.template_name}-${row.language}`"
              class="hover:bg-n-slate-2 dark:hover:bg-n-solid-3 transition-colors"
            >
              <td
                class="py-4 px-5 text-sm font-medium text-n-slate-12 max-w-[220px] truncate"
                :title="row.template_name"
              >
                {{ row.template_name }}
              </td>
              <td class="py-4 px-5 text-sm text-n-slate-11">
                {{ row.language || '—' }}
              </td>
              <td
                class="py-4 px-5 text-sm text-right text-n-slate-12 tabular-nums"
              >
                {{ row.total.toLocaleString() }}
              </td>
              <td
                class="py-4 px-5 text-sm text-right text-n-slate-12 tabular-nums"
              >
                {{ row.sent.toLocaleString() }}
              </td>
              <td
                class="py-4 px-5 text-sm text-right text-n-slate-12 tabular-nums"
              >
                {{ row.delivered.toLocaleString() }}
              </td>
              <td
                class="py-4 px-5 text-sm text-right text-n-slate-12 tabular-nums"
              >
                {{ row.read.toLocaleString() }}
              </td>
              <td
                class="py-4 px-5 text-sm text-right tabular-nums"
                :class="
                  row.failed > 0
                    ? 'text-n-ruby-11 font-medium'
                    : 'text-n-slate-10'
                "
              >
                {{ row.failed.toLocaleString() }}
              </td>
              <td
                class="py-4 px-5 text-sm text-right text-n-slate-12 tabular-nums"
              >
                {{ row.delivery_rate }}%
              </td>
              <td
                class="py-4 px-5 text-sm text-right text-n-slate-12 tabular-nums"
              >
                {{ row.read_rate }}%
              </td>
            </tr>
          </tbody>

          <tfoot
            v-if="filteredRecords.length > 1"
            class="border-t border-n-container bg-n-solid-1"
          >
            <tr>
              <td
                class="py-3 px-5 text-sm font-semibold text-n-slate-12"
                colspan="2"
              >
                {{ $t('WHATSAPP_TEMPLATE_REPORTS.TABLE.TOTAL_ROW') }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold text-n-slate-12 tabular-nums"
              >
                {{ totals.total.toLocaleString() }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold text-n-slate-12 tabular-nums"
              >
                {{ totals.sent.toLocaleString() }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold text-n-slate-12 tabular-nums"
              >
                {{ totals.delivered.toLocaleString() }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold text-n-slate-12 tabular-nums"
              >
                {{ totals.read.toLocaleString() }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold tabular-nums"
                :class="
                  totals.failed > 0 ? 'text-n-ruby-11' : 'text-n-slate-10'
                "
              >
                {{ totals.failed.toLocaleString() }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold text-n-slate-12 tabular-nums"
              >
                {{ rate(totals.delivered, totals.sent) }}
              </td>
              <td
                class="py-3 px-5 text-sm text-right font-semibold text-n-slate-12 tabular-nums"
              >
                {{ rate(totals.read, totals.sent) }}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  </div>
</template>
