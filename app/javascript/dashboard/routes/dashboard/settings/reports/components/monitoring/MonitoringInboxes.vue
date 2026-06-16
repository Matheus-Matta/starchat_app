<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatTime } from '@chatwoot/utils';

const props = defineProps({
  inboxes: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const inboxList = computed(() => props.inboxes || []);

const fmt = v => (v != null ? formatTime(v) : '--');

const inboxStatusMap = computed(() => ({
  online: {
    dot: 'bg-n-teal-9',
    text: 'text-n-teal-11',
    label: t('MONITORING_REPORTS.STATUS.ONLINE'),
  },
  warning: {
    dot: 'bg-n-amber-9',
    text: 'text-n-amber-11',
    label: t('MONITORING_REPORTS.STATUS.WARNING'),
  },
  offline: {
    dot: 'bg-n-ruby-9',
    text: 'text-n-ruby-11',
    label: t('MONITORING_REPORTS.STATUS.OFFLINE'),
  },
}));

const inboxStatus = s =>
  inboxStatusMap.value[s] || inboxStatusMap.value.offline;
</script>

<template>
  <section
    class="shadow-sm outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-4 py-5 lg:px-5"
    data-testid="monitoring-inboxes"
  >
    <header class="mb-4 flex flex-wrap items-center justify-between gap-2">
      <div>
        <h3 class="mb-0 text-base font-medium text-n-slate-12">
          {{ t('MONITORING_REPORTS.INBOXES.TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11">
          {{ t('MONITORING_REPORTS.INBOXES.SUBTITLE') }}
        </p>
      </div>
    </header>

    <div
      v-if="!inboxList.length && !isLoading"
      class="rounded-xl border border-n-weak bg-n-solid-1 px-6 py-10 text-center"
    >
      <h4 class="text-base font-semibold text-n-slate-12">
        {{ t('MONITORING_REPORTS.INBOXES.EMPTY_TITLE') }}
      </h4>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('MONITORING_REPORTS.INBOXES.EMPTY_MESSAGE') }}
      </p>
    </div>

    <div
      v-else
      class="overflow-x-auto rounded-xl border border-n-weak"
      data-testid="monitoring-inbox-table"
    >
      <table class="w-full">
        <thead class="bg-n-slate-1">
          <tr>
            <th
              class="ltr:first:rounded-tl-xl rtl:first:rounded-tr-xl py-3 px-5 text-left font-medium text-sm text-n-slate-12"
            >
              {{ t('MONITORING_REPORTS.INBOXES.TITLE_COL') }}
            </th>
            <th class="py-3 px-5 text-left font-medium text-sm text-n-slate-12">
              {{ t('MONITORING_REPORTS.TABLE.STATUS') }}
            </th>
            <th
              class="py-3 px-5 text-right font-medium text-sm text-n-slate-12"
            >
              {{ t('MONITORING_REPORTS.TABLE.CONVERSATIONS') }}
            </th>
            <th
              class="py-3 px-5 text-right font-medium text-sm text-n-slate-12"
            >
              {{ t('MONITORING_REPORTS.TABLE.AVG_FIRST_RESPONSE') }}
            </th>
            <th
              class="py-3 px-5 text-right font-medium text-sm text-n-slate-12"
            >
              {{ t('MONITORING_REPORTS.TABLE.AVG_RESOLUTION') }}
            </th>
            <th
              class="py-3 px-5 text-right font-medium text-sm text-n-slate-12"
            >
              {{ t('MONITORING_REPORTS.TABLE.AVG_REPLY') }}
            </th>
            <th
              class="ltr:last:rounded-tr-xl rtl:last:rounded-tl-xl py-3 px-5 text-right font-medium text-sm text-n-slate-12"
            >
              {{ t('MONITORING_REPORTS.TABLE.RESOLUTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr v-if="isLoading && !inboxList.length" class="text-center">
            <td colspan="7" class="py-8 text-sm text-n-slate-11">
              {{ t('REPORT.LOADING_CHART') }}
            </td>
          </tr>
          <tr
            v-for="inbox in inboxList"
            :key="inbox.id"
            class="transition-colors hover:bg-n-alpha-1"
          >
            <td class="py-3 px-5">
              <p
                class="max-w-[200px] truncate text-sm font-medium text-n-slate-12"
              >
                {{ inbox.name }}
              </p>
            </td>
            <td class="py-3 px-5">
              <span
                class="inline-flex items-center gap-1.5 text-xs font-medium"
                :class="inboxStatus(inbox.status).text"
              >
                <span
                  class="h-1.5 w-1.5 rounded-full"
                  :class="inboxStatus(inbox.status).dot"
                />
                {{ inboxStatus(inbox.status).label }}
              </span>
            </td>
            <td
              class="py-3 px-5 text-right text-sm tabular-nums text-n-slate-12"
            >
              {{ inbox.conversations_count ?? 0 }}
            </td>
            <td
              class="py-3 px-5 text-right text-sm tabular-nums text-n-slate-11"
            >
              {{ fmt(inbox.avg_first_response_time) }}
            </td>
            <td
              class="py-3 px-5 text-right text-sm tabular-nums text-n-slate-11"
            >
              {{ fmt(inbox.avg_resolution_time) }}
            </td>
            <td
              class="py-3 px-5 text-right text-sm tabular-nums text-n-slate-11"
            >
              {{ fmt(inbox.avg_reply_time) }}
            </td>
            <td
              class="py-3 px-5 text-right text-sm tabular-nums text-n-slate-12"
            >
              {{ inbox.resolved_conversations_count ?? 0 }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
