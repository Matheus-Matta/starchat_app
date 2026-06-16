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
});

const { t } = useI18n();

const s = computed(() => props.summary || {});
</script>

<template>
  <section
    class="outline outline-1 outline-n-container rounded-xl bg-n-solid-2 px-4 py-3 shadow-sm lg:px-5"
    data-testid="monitoring-summary"
  >
    <div class="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm">
      <span
        class="flex items-center gap-1.5 rounded-full bg-n-teal-3 px-2.5 py-0.5 text-xs font-semibold text-n-teal-11"
      >
        <span class="size-1.5 animate-pulse rounded-full bg-n-teal-9" />
        {{ t('MONITORING_REPORTS.LIVE_BADGE') }}
      </span>

      <div class="flex items-center gap-2">
        <span class="font-medium text-n-slate-12">
          {{ t('MONITORING_REPORTS.SECTIONS.INBOXES') }}
        </span>
        <span class="text-n-slate-11">
          {{ s.total_inboxes }}
          {{ t('MONITORING_REPORTS.SUMMARY.TOTAL_INBOXES_SHORT') }}
        </span>
        <span class="text-n-teal-11">
          ● {{ s.online_inboxes }} {{ t('MONITORING_REPORTS.STATUS.ONLINE') }}
        </span>
        <span v-if="s.warning_inboxes" class="text-n-amber-11">
          ● {{ s.warning_inboxes }}
          {{ t('MONITORING_REPORTS.STATUS_FILTER.WARNING') }}
        </span>
        <span v-if="s.offline_inboxes" class="text-n-ruby-11">
          ● {{ s.offline_inboxes }} {{ t('MONITORING_REPORTS.STATUS.OFFLINE') }}
        </span>
      </div>

      <div class="hidden sm:block h-4 w-px bg-n-weak" />

      <div class="flex items-center gap-2">
        <span class="font-medium text-n-slate-12">
          {{ t('MONITORING_REPORTS.SECTIONS.AGENTS') }}
        </span>
        <span class="text-n-slate-11">
          {{ s.total_agents }}
          {{ t('MONITORING_REPORTS.SUMMARY.TOTAL_AGENTS_SHORT') }}
        </span>
        <span class="text-n-teal-11">
          ● {{ s.agents_available }}
          {{ t('MONITORING_REPORTS.SUMMARY.AGENTS_AVAILABLE') }}
        </span>
        <span v-if="s.agents_busy" class="text-n-amber-11">
          ● {{ s.agents_busy }}
          {{ t('MONITORING_REPORTS.SUMMARY.AGENTS_BUSY') }}
        </span>
        <span v-if="s.agents_offline" class="text-n-slate-11">
          ● {{ s.agents_offline }}
          {{ t('MONITORING_REPORTS.STATUS.OFFLINE') }}
        </span>
      </div>

      <div class="hidden sm:block h-4 w-px bg-n-weak" />

      <div class="flex items-center gap-1.5">
        <span
          class="text-base font-semibold tabular-nums text-n-slate-12"
          :class="{ 'opacity-50': isLoading }"
        >
          {{ s.total_active_conversations }}
        </span>
        <span class="text-n-slate-11">
          {{ t('MONITORING_REPORTS.SUMMARY.TOTAL_ACTIVE_CONVERSATIONS') }}
        </span>
      </div>
    </div>
  </section>
</template>
