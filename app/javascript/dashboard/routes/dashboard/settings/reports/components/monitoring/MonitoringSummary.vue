<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  summary: {
    type: Object,
    required: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  collapsed: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const metricBlueprint = [
  {
    key: 'total_inboxes',
    labelKey: 'MONITORING_REPORTS.SUMMARY.TOTAL_INBOXES',
    icon: 'i-ph-tray-bold',
    valueClass: 'text-n-slate-12',
  },
  {
    key: 'online_inboxes',
    labelKey: 'MONITORING_REPORTS.SUMMARY.ONLINE_INBOXES',
    icon: 'i-ph-broadcast-tower',
    valueClass: 'text-n-teal-11',
  },
  {
    key: 'warning_inboxes',
    labelKey: 'MONITORING_REPORTS.SUMMARY.WARNING_INBOXES',
    icon: 'i-ph-warning-circle',
    valueClass: 'text-n-amber-11',
  },
  {
    key: 'offline_inboxes',
    labelKey: 'MONITORING_REPORTS.SUMMARY.OFFLINE_INBOXES',
    icon: 'i-ph-power',
    valueClass: 'text-n-ruby-11',
  },
  {
    key: 'total_agents',
    labelKey: 'MONITORING_REPORTS.SUMMARY.TOTAL_AGENTS',
    icon: 'i-ph-users-three',
    valueClass: 'text-n-slate-12',
  },
  {
    key: 'agents_available',
    labelKey: 'MONITORING_REPORTS.SUMMARY.AGENTS_AVAILABLE',
    icon: 'i-ph-lightning',
    valueClass: 'text-n-teal-11',
  },
  {
    key: 'agents_busy',
    labelKey: 'MONITORING_REPORTS.SUMMARY.AGENTS_BUSY',
    icon: 'i-ph-timer',
    valueClass: 'text-n-amber-11',
  },
  {
    key: 'agents_offline',
    labelKey: 'MONITORING_REPORTS.SUMMARY.AGENTS_OFFLINE',
    icon: 'i-ph-moon-stars',
    valueClass: 'text-n-ruby-11',
  },
  {
    key: 'total_active_conversations',
    labelKey: 'MONITORING_REPORTS.SUMMARY.TOTAL_ACTIVE_CONVERSATIONS',
    icon: 'i-ph-chats-circle',
    valueClass: 'text-n-slate-12',
  },
];

const metrics = computed(() => {
  const s = props.summary || {};
  return metricBlueprint.map(item => ({
    ...item,
    label: t(item.labelKey),
    value: s[item.key] ?? 0,
  }));
});
</script>

<template>
  <section
    class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
    data-testid="monitoring-summary"
  >
    <header class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <div class="flex items-center gap-2">
          <h2 class="mb-0 text-n-slate-12 font-medium text-lg">
            {{ t('MONITORING_REPORTS.SUMMARY.TITLE') }}
          </h2>
          <span
            class="flex flex-row items-center py-0.5 px-2 rounded bg-n-teal-3 text-xs"
          >
            <span
              class="bg-n-teal-9 h-1 w-1 rounded-full mr-1 rtl:mr-0 rtl:ml-0"
            />
            <span class="text-xs text-n-teal-11">
              {{ t('MONITORING_REPORTS.LIVE_BADGE') }}
            </span>
          </span>
        </div>
        <p class="text-sm text-n-slate-11 mt-1">
          {{ t('MONITORING_REPORTS.DESCRIPTION') }}
        </p>
      </div>
    </header>

    <div
      v-if="collapsed"
      class="mt-4 rounded-xl border border-dashed border-n-weak bg-n-solid-1 px-5 py-6 text-sm text-n-slate-11"
    >
      {{ t('MONITORING_REPORTS.SECTIONS.HIDDEN_COPY') }}
    </div>

    <div
      v-else
      class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
    >
      <article
        v-for="metric in metrics"
        :key="metric.label"
        class="rounded-xl border border-n-weak bg-n-solid-1 px-5 py-4 text-n-slate-12"
      >
        <div class="flex items-center justify-between gap-3">
          <p
            class="text-xs font-semibold uppercase tracking-wide text-n-slate-11 line-clamp-2"
          >
            {{ metric.label }}
          </p>
          <span :class="metric.icon" class="text-lg text-n-slate-10" />
        </div>
        <p class="mt-3 text-3xl font-semibold tabular-nums">
          <span
            v-if="isLoading"
            class="inline-flex h-8 w-20 animate-pulse rounded-lg bg-n-alpha-3"
          />
          <span
            v-else
            data-testid="monitoring-summary-value"
            :class="metric.valueClass"
          >
            {{ metric.value }}
          </span>
        </p>
      </article>
    </div>
  </section>
</template>
