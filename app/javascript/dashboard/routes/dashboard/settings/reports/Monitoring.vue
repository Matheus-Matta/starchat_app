<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useDebounceFn, useFullscreen } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import startOfDay from 'date-fns/startOfDay';
import getUnixTime from 'date-fns/getUnixTime';

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
import { useMapGetter } from 'dashboard/composables/store';

const store = useStore();
const { t } = useI18n();
const monitoringRoot = ref(null);

const summary = computed(() => store.getters['monitoringReports/getSummary']);
const inboxes = computed(() => store.getters['monitoringReports/getInboxes']);
const agents = computed(() => store.getters['monitoringReports/getAgents']);
const agentSummaries = computed(
  () => store.getters['monitoringReports/getAgentSummaries']
);
const inboxSummaries = computed(
  () => store.getters['monitoringReports/getInboxSummaries']
);
const uiFlags = computed(
  () => store.getters['monitoringReports/getMonitoringUIFlags'] || {}
);
const allTeams = useMapGetter('teams/getTeams');

const collapsedSections = reactive({
  summary: false,
  inboxes: false,
  agents: false,
});

const filters = reactive({
  inboxId: null,
  inboxStatus: 'all',
  agentId: null,
  agentTeamId: null,
});

const toggleSection = sectionKey => {
  collapsedSections[sectionKey] = !collapsedSections[sectionKey];
};

// Merge snapshot agents (name, status, team_ids) with today's report summaries
const mergedAgents = computed(() => {
  const summaryMap = Object.fromEntries(
    (agentSummaries.value || []).map(s => [s.id, s])
  );
  return (agents.value || []).map(agent => ({
    ...agent,
    ...(summaryMap[agent.id] || {}),
  }));
});

// Merge snapshot inboxes (name, channel, status) with today's report summaries
const mergedInboxes = computed(() => {
  const summaryMap = Object.fromEntries(
    (inboxSummaries.value || []).map(s => [s.id, s])
  );
  return (inboxes.value || []).map(inbox => ({
    ...inbox,
    ...(summaryMap[inbox.id] || {}),
  }));
});

const filteredInboxes = computed(() =>
  mergedInboxes.value
    .filter(inbox => !filters.inboxId || inbox.id === filters.inboxId)
    .filter(
      inbox =>
        filters.inboxStatus === 'all' || inbox.status === filters.inboxStatus
    )
);

const filteredAgents = computed(() =>
  mergedAgents.value
    .filter(agent => !filters.agentId || agent.id === filters.agentId)
    .filter(
      agent =>
        !filters.agentTeamId ||
        (agent.team_ids || []).includes(filters.agentTeamId)
    )
);

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

const todaySince = computed(() => getUnixTime(startOfDay(new Date())));
const todayUntil = computed(() => Math.floor(Date.now() / 1000));

const fetchSnapshot = () => store.dispatch('monitoringReports/fetchSnapshot');

const fetchSummaries = () => {
  store.dispatch('monitoringReports/fetchAgentSummaries', {
    since: todaySince.value,
    until: todayUntil.value,
  });
  store.dispatch('monitoringReports/fetchInboxSummaries', {
    since: todaySince.value,
    until: todayUntil.value,
  });
};

const fetchAll = () => {
  fetchSnapshot();
  fetchSummaries();
};

const handleManualRefresh = () => fetchAll();

const debouncedRealtimeRefresh = useDebounceFn(() => fetchAll(), 1200, {
  maxWait: 5000,
});

useEmitter('fetch_conversation_stats', () => debouncedRealtimeRefresh());
useEmitter(BUS_EVENTS.WEBSOCKET_RECONNECT, () => debouncedRealtimeRefresh());
useEmitter('evolution:connection_update', () => debouncedRealtimeRefresh());
useEmitter('monitoring:refresh_snapshot', () => debouncedRealtimeRefresh());

const { isFullscreen, toggle: toggleFullscreen } =
  useFullscreen(monitoringRoot);
const fullscreenIcon = computed(() =>
  isFullscreen.value ? 'i-ph-corners-in' : 'i-ph-corners-out'
);

// Select options
const inboxStatusOptions = computed(() => [
  {
    value: 'all',
    label: t('MONITORING_REPORTS.STATUS_FILTER.ALL_INBOXES'),
  },
  { value: 'online', label: t('MONITORING_REPORTS.STATUS.ONLINE') },
  {
    value: 'warning',
    label: t('MONITORING_REPORTS.STATUS_FILTER.WARNING'),
  },
  { value: 'offline', label: t('MONITORING_REPORTS.STATUS.OFFLINE') },
]);

const teamOptions = computed(() => [
  { value: null, label: t('MONITORING_REPORTS.FILTERS.ALL_TEAMS') },
  ...allTeams.value.map(team => ({ value: team.id, label: team.name })),
]);

const inboxOptions = computed(() => [
  {
    value: null,
    label: t('MONITORING_REPORTS.STATUS_FILTER.ALL_INBOXES'),
  },
  ...(inboxes.value || []).map(i => ({ value: i.id, label: i.name })),
]);

const agentOptions = computed(() => [
  {
    value: null,
    label: t('MONITORING_REPORTS.STATUS_FILTER.ALL_AGENTS'),
  },
  ...(agents.value || []).map(a => ({ value: a.id, label: a.name })),
]);

const getLabel = (options, value, fallback) =>
  options.find(o => o.value === value)?.label || fallback;

const inboxStatusLabel = computed(() =>
  getLabel(
    inboxStatusOptions.value,
    filters.inboxStatus,
    t('MONITORING_REPORTS.STATUS_FILTER.ALL_INBOXES')
  )
);
const teamLabel = computed(() =>
  getLabel(
    teamOptions.value,
    filters.agentTeamId,
    t('MONITORING_REPORTS.FILTERS.ALL_TEAMS')
  )
);
const inboxLabel = computed(() =>
  getLabel(
    inboxOptions.value,
    filters.inboxId,
    t('MONITORING_REPORTS.STATUS_FILTER.ALL_INBOXES')
  )
);
const agentLabel = computed(() =>
  getLabel(
    agentOptions.value,
    filters.agentId,
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

onMounted(() => {
  fetchAll();
  store.dispatch('teams/get');
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

    <!-- Control bar -->
    <section
      class="outline outline-1 outline-n-container rounded-xl bg-n-solid-2 px-4 py-4 shadow-sm lg:px-5"
      :class="isFullscreen ? 'sticky top-0 z-30' : ''"
    >
      <div v-if="isFullscreen" class="mb-4 flex items-center justify-between">
        <h1 class="text-n-slate-12 font-medium text-lg">
          {{ t('MONITORING_REPORTS.HEADER') }}
        </h1>
      </div>

      <!-- Filters: two labelled groups -->
      <div class="flex flex-wrap items-end gap-x-6 gap-y-4">
        <!-- Inboxes group -->
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-semibold uppercase text-n-slate-11">
            {{ t('MONITORING_REPORTS.SECTIONS.INBOXES') }}
          </span>
          <div class="flex flex-wrap gap-2">
            <SelectMenu
              sub-menu-position="bottom"
              :options="inboxOptions"
              :label="inboxLabel"
              :model-value="filters.inboxId"
              @update:model-value="v => (filters.inboxId = v)"
            />
            <SelectMenu
              sub-menu-position="bottom"
              :options="inboxStatusOptions"
              :label="inboxStatusLabel"
              :model-value="filters.inboxStatus"
              @update:model-value="v => (filters.inboxStatus = v)"
            />
          </div>
        </div>

        <div class="hidden md:block h-8 w-px self-end bg-n-weak" />

        <!-- Agents group -->
        <div class="flex flex-col gap-1.5">
          <span class="text-xs font-semibold uppercase text-n-slate-11">
            {{ t('MONITORING_REPORTS.SECTIONS.AGENTS') }}
          </span>
          <div class="flex flex-wrap gap-2">
            <SelectMenu
              sub-menu-position="bottom"
              :options="teamOptions"
              :label="teamLabel"
              :model-value="filters.agentTeamId"
              @update:model-value="v => (filters.agentTeamId = v)"
            />
            <SelectMenu
              sub-menu-position="bottom"
              :options="agentOptions"
              :label="agentLabel"
              :model-value="filters.agentId"
              @update:model-value="v => (filters.agentId = v)"
            />
          </div>
        </div>
      </div>

      <!-- Bottom bar: section toggles + refresh -->
      <div
        class="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-n-weak pt-3"
      >
        <ButtonGroup class="flex flex-wrap gap-1.5">
          <Button
            v-for="section in sectionButtons"
            :key="section.key"
            size="xs"
            :label="section.label"
            color="slate"
            :variant="section.collapsed ? 'ghost' : 'slate'"
            :aria-pressed="!section.collapsed"
            @click="toggleSection(section.key)"
          />
        </ButtonGroup>

        <div class="flex flex-wrap items-center gap-2 text-sm text-n-slate-11">
          <span>{{ lastUpdatedLabel }}</span>
          <Spinner v-if="uiFlags.isFetching" :size="12" />
          <ButtonGroup class="flex items-center gap-1.5">
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
    </section>

    <!-- Error -->
    <div
      v-if="uiFlags.error"
      class="rounded-xl border border-rose-300/60 bg-rose-500/5 px-6 py-4 text-sm text-rose-500"
    >
      <p class="font-semibold">
        {{ t('MONITORING_REPORTS.ERROR.TITLE') }}
      </p>
      <p class="mt-1 text-n-slate-12">{{ uiFlags.error }}</p>
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
