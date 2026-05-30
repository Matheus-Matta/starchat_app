<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useDebounceFn, useFullscreen } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

import ReportHeader from './components/ReportHeader.vue';
import MonitoringSummary from './components/monitoring/MonitoringSummary.vue';
import MonitoringInboxes from './components/monitoring/MonitoringInboxes.vue';
import MonitoringAgents from './components/monitoring/MonitoringAgents.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ButtonGroup from 'dashboard/components-next/buttonGroup/ButtonGroup.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useEmitter } from 'dashboard/composables/emitter';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const store = useStore();
const { t } = useI18n();
const monitoringRoot = ref(null);

const summary = computed(() => store.getters['monitoringReports/getSummary']);
const inboxes = computed(() => store.getters['monitoringReports/getInboxes']);
const agents = computed(() => store.getters['monitoringReports/getAgents']);
const uiFlags = computed(
  () => store.getters['monitoringReports/getMonitoringUIFlags'] || {}
);

const collapsedSections = reactive({
  summary: false,
  inboxes: false,
  agents: false,
});

const filters = reactive({
  inboxSearch: '',
  inboxStatus: 'all',
  agentSearch: '',
  agentStatus: 'all',
});

const toggleSection = sectionKey => {
  collapsedSections[sectionKey] = !collapsedSections[sectionKey];
};

const normalizeSearch = value => value?.toString().trim().toLowerCase() || '';

const channelDisplayName = channelType => {
  if (!channelType) return '';
  const raw = channelType.split('::').pop();
  return raw.replace(/([a-z])([A-Z])/g, '$1 $2');
};

const filteredInboxes = computed(() => {
  const query = normalizeSearch(filters.inboxSearch);
  const list = inboxes.value || [];
  return list
    .filter(inbox => {
      return (
        filters.inboxStatus === 'all' ||
        !inbox?.status ||
        inbox.status === filters.inboxStatus
      );
    })
    .filter(inbox => {
      if (!query) return true;
      const channelName = channelDisplayName(inbox.channel_type);
      return [inbox.name, channelName]
        .filter(Boolean)
        .some(field => field.toLowerCase().includes(query));
    });
});

const filteredAgents = computed(() => {
  const query = normalizeSearch(filters.agentSearch);
  const list = agents.value || [];
  return list
    .filter(agent => {
      return (
        filters.agentStatus === 'all' ||
        !agent?.availability_status ||
        agent.availability_status === filters.agentStatus
      );
    })
    .filter(agent => {
      if (!query) return true;
      return [agent.name, agent.email]
        .filter(Boolean)
        .some(field => field.toLowerCase().includes(query));
    });
});

const locale = computed(() => window?.I18n?.locale || 'en');
const timeFormatter = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      day: '2-digit',
      month: 'short',
    })
);

const lastUpdatedLabel = computed(() => {
  if (!uiFlags.value?.lastSyncedAt) {
    return t('MONITORING_REPORTS.NEVER_SYNCED');
  }
  return t('MONITORING_REPORTS.LAST_UPDATED', {
    time: timeFormatter.value.format(new Date(uiFlags.value.lastSyncedAt)),
  });
});

const fetchSnapshot = () => store.dispatch('monitoringReports/fetchSnapshot');
const handleManualRefresh = () => fetchSnapshot();

const debouncedRealtimeRefresh = useDebounceFn(
  () => {
    fetchSnapshot();
  },
  1200,
  { maxWait: 5000 }
);

useEmitter('fetch_conversation_stats', () => debouncedRealtimeRefresh());
useEmitter(BUS_EVENTS.WEBSOCKET_RECONNECT, () => debouncedRealtimeRefresh());
useEmitter('evolution:connection_update', () => debouncedRealtimeRefresh());
useEmitter('monitoring:refresh_snapshot', () => debouncedRealtimeRefresh());

const { isFullscreen, toggle: toggleFullscreen } =
  useFullscreen(monitoringRoot);
const fullscreenIcon = computed(() =>
  isFullscreen.value ? 'i-ph-corners-in' : 'i-ph-corners-out'
);

const inboxStatusOptions = computed(() => [
  {
    value: 'all',
    label: t('MONITORING_REPORTS.STATUS_FILTER.ALL_INBOXES'),
  },
  {
    value: 'online',
    label: t('MONITORING_REPORTS.STATUS.ONLINE'),
  },
  {
    value: 'warning',
    label: t('MONITORING_REPORTS.STATUS_FILTER.WARNING'),
  },
  {
    value: 'offline',
    label: t('MONITORING_REPORTS.STATUS.OFFLINE'),
  },
]);

const agentStatusOptions = computed(() => [
  {
    value: 'all',
    label: t('MONITORING_REPORTS.STATUS_FILTER.ALL_AGENTS'),
  },
  {
    value: 'online',
    label: t('MONITORING_REPORTS.STATUS.ONLINE'),
  },
  {
    value: 'busy',
    label: t('MONITORING_REPORTS.STATUS_FILTER.BUSY'),
  },
  {
    value: 'offline',
    label: t('MONITORING_REPORTS.STATUS.OFFLINE'),
  },
]);

const getSelectedLabel = (options, value, fallback) => {
  const found = options.find(option => option.value === value);
  return found?.label || fallback;
};

const inboxStatusLabel = computed(() =>
  getSelectedLabel(
    inboxStatusOptions.value,
    filters.inboxStatus,
    t('MONITORING_REPORTS.STATUS_FILTER.ALL_INBOXES')
  )
);

const agentStatusLabel = computed(() =>
  getSelectedLabel(
    agentStatusOptions.value,
    filters.agentStatus,
    t('MONITORING_REPORTS.STATUS_FILTER.ALL_AGENTS')
  )
);

const sectionButtons = computed(() => [
  {
    key: 'summary',
    label: t('MONITORING_REPORTS.SECTIONS.SUMMARY'),
    collapsed: collapsedSections.summary,
  },
  {
    key: 'inboxes',
    label: t('MONITORING_REPORTS.SECTIONS.INBOXES'),
    collapsed: collapsedSections.inboxes,
  },
  {
    key: 'agents',
    label: t('MONITORING_REPORTS.SECTIONS.AGENTS'),
    collapsed: collapsedSections.agents,
  },
]);

const handleSectionToggle = sectionKey => toggleSection(sectionKey);

onMounted(() => {
  fetchSnapshot();
});
</script>

<template>
  <div
    ref="monitoringRoot"
    class="monitoring-root flex flex-col gap-4 pb-6"
    :class="
      isFullscreen ? 'bg-n-background px-3 py-3 h-screen overflow-auto' : ''
    "
  >
    <ReportHeader
      v-if="!isFullscreen"
      :header-title="t('MONITORING_REPORTS.HEADER')"
      :header-description="t('MONITORING_REPORTS.DESCRIPTION')"
    />

    <section
      class="outline outline-1 outline-n-container rounded-xl bg-n-solid-2 px-4 py-4 shadow-sm lg:px-5"
      :class="isFullscreen ? 'sticky top-0 z-30' : ''"
    >
      <div class="flex flex-col gap-4">
        <div v-if="isFullscreen" class="flex items-center justify-between">
          <h1 class="text-n-slate-12 font-medium text-lg">
            {{ t('MONITORING_REPORTS.HEADER') }}
          </h1>
          <div class="flex items-center gap-2">
            <span class="text-sm text-n-slate-11">{{ lastUpdatedLabel }}</span>
            <span
              v-if="uiFlags.isFetching"
              class="inline-flex items-center gap-2 text-sm text-n-slate-12"
            >
              <Spinner :size="14" />
              {{ t('REPORT.LOADING_CHART') }}
            </span>
          </div>
        </div>

        <div class="grid gap-y-3 gap-x-3 md:grid-cols-2 xl:grid-cols-4">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-semibold uppercase text-n-slate-11">
              {{ t('MONITORING_REPORTS.FILTERS.INBOX_SEARCH_LABEL') }}
            </label>
            <woot-input
              v-model.trim="filters.inboxSearch"
              type="search"
              data-testid="monitoring-inbox-search"
              :placeholder="
                t('MONITORING_REPORTS.FILTERS.INBOX_SEARCH_PLACEHOLDER')
              "
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-semibold uppercase text-n-slate-11">
              {{ t('MONITORING_REPORTS.FILTERS.INBOX_STATUS') }}
            </label>
            <SelectMenu
              full-width
              sub-menu-position="bottom"
              :options="inboxStatusOptions"
              :label="inboxStatusLabel"
              :model-value="filters.inboxStatus"
              @update:model-value="value => (filters.inboxStatus = value)"
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-semibold uppercase text-n-slate-11">
              {{ t('MONITORING_REPORTS.FILTERS.AGENT_SEARCH_LABEL') }}
            </label>
            <woot-input
              v-model.trim="filters.agentSearch"
              type="search"
              data-testid="monitoring-agent-search"
              :placeholder="
                t('MONITORING_REPORTS.FILTERS.AGENT_SEARCH_PLACEHOLDER')
              "
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-semibold uppercase text-n-slate-11">
              {{ t('MONITORING_REPORTS.FILTERS.AGENT_STATUS') }}
            </label>
            <SelectMenu
              full-width
              sub-menu-position="bottom"
              :options="agentStatusOptions"
              :label="agentStatusLabel"
              :model-value="filters.agentStatus"
              @update:model-value="value => (filters.agentStatus = value)"
            />
          </div>
        </div>

        <div
          class="flex flex-wrap items-center justify-between gap-3 border-t border-n-weak pt-3"
        >
          <div class="flex flex-wrap items-center gap-3">
            <span class="text-xs font-semibold uppercase text-n-slate-11">
              {{ t('MONITORING_REPORTS.SECTIONS.TOGGLE_LABEL') }}
            </span>
            <ButtonGroup class="flex flex-wrap gap-2">
              <Button
                v-for="section in sectionButtons"
                :key="section.key"
                size="xs"
                :label="section.label"
                color="slate"
                :variant="section.collapsed ? 'ghost' : 'slate'"
                class="capitalize"
                :aria-pressed="!section.collapsed"
                @click="handleSectionToggle(section.key)"
              />
            </ButtonGroup>
          </div>

          <div
            class="flex flex-wrap items-center gap-2 text-sm text-n-slate-11"
          >
            <span v-if="!isFullscreen">{{ lastUpdatedLabel }}</span>
            <span
              v-if="uiFlags.isFetching && !isFullscreen"
              class="inline-flex items-center gap-2 text-n-slate-12"
            >
              <Spinner :size="14" />
              {{ t('REPORT.LOADING_CHART') }}
            </span>

            <ButtonGroup class="flex items-center gap-2">
              <Button
                size="sm"
                variant="slate"
                :label="t('MONITORING_REPORTS.ACTIONS.REFRESH')"
                icon="i-ph-arrow-clockwise"
                :disabled="uiFlags.isFetching"
                @click="handleManualRefresh"
              />
              <Button
                size="sm"
                variant="ghost"
                :label="
                  isFullscreen
                    ? t('MONITORING_REPORTS.ACTIONS.EXIT_FULLSCREEN')
                    : t('MONITORING_REPORTS.ACTIONS.ENTER_FULLSCREEN')
                "
                :icon="fullscreenIcon"
                @click="toggleFullscreen"
              />
            </ButtonGroup>
          </div>
        </div>
      </div>
    </section>

    <div
      v-if="uiFlags.error"
      class="rounded-xl border border-rose-300/60 bg-rose-500/5 px-6 py-4 text-sm text-rose-500"
    >
      <p class="font-semibold">
        {{ t('MONITORING_REPORTS.ERROR.TITLE') }}
      </p>
      <p class="mt-1 text-n-slate-12">
        {{ uiFlags.error }}
      </p>
      <Button
        size="sm"
        variant="ghost"
        class="mt-2"
        :label="t('MONITORING_REPORTS.ERROR.ACTION')"
        @click="handleManualRefresh"
      />
    </div>

    <MonitoringSummary
      v-if="!collapsedSections.summary"
      :summary="summary"
      :is-loading="uiFlags.isFetching"
    />

    <MonitoringInboxes
      v-if="!collapsedSections.inboxes"
      :inboxes="filteredInboxes"
      :is-loading="uiFlags.isFetching"
    />

    <MonitoringAgents
      v-if="!collapsedSections.agents"
      :agents="filteredAgents"
      :is-loading="uiFlags.isFetching"
    />
  </div>
</template>

<style scoped>
:global(.monitoring-root:fullscreen) {
  background: transparent;
}
</style>
