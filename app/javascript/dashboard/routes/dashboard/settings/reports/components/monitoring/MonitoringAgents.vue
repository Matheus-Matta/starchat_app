<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  agents: {
    type: Array,
    default: () => [],
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

const availabilityTone = {
  online: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-4',
  busy: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-4',
  offline: 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-4',
};

const statusLabel = status => {
  if (status === 'busy') {
    return t('MONITORING_REPORTS.STATUS_FILTER.BUSY');
  }
  if (status === 'online') {
    return t('MONITORING_REPORTS.STATUS_FILTER.ONLINE');
  }
  if (status === 'offline') {
    return t('MONITORING_REPORTS.STATUS_FILTER.OFFLINE');
  }
  return t('MONITORING_REPORTS.STATUS_FILTER.OFFLINE');
};

const formatTimestamp = isoString => {
  if (!isoString) {
    return t('MONITORING_REPORTS.AGENTS.NEVER');
  }
  return timeFormatter.value.format(new Date(isoString));
};

const agentList = computed(() => props.agents || []);

const statusBreakdown = computed(() => {
  const list = agentList.value;
  return {
    online: list.filter(agent => agent.availability_status === 'online').length,
    busy: list.filter(agent => agent.availability_status === 'busy').length,
    offline: list.filter(agent => agent.availability_status === 'offline')
      .length,
  };
});
</script>

<template>
  <section
    class="shadow-sm outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-4 py-5 lg:px-5"
    data-testid="monitoring-agents"
  >
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h3 class="text-n-slate-12 font-medium text-lg mb-0">
          {{ t('MONITORING_REPORTS.AGENTS.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('MONITORING_REPORTS.AGENTS.SUBTITLE') }}
        </p>
      </div>
    </header>

    <div
      v-if="collapsed"
      class="mt-4 rounded-xl border border-dashed border-n-weak bg-n-solid-1 px-5 py-6 text-sm text-n-slate-11"
    >
      {{ t('MONITORING_REPORTS.SECTIONS.HIDDEN_COPY') }}
    </div>

    <template v-else>
      <div class="mt-6 flex flex-wrap gap-2 text-xs font-semibold">
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-teal-3 text-n-teal-11 border border-n-teal-4"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.AGENTS_AVAILABLE') }}:
          {{ statusBreakdown.online }}
        </span>
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-amber-3 text-n-amber-11 border border-n-amber-4"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.AGENTS_BUSY') }}:
          {{ statusBreakdown.busy }}
        </span>
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-4"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.AGENTS_OFFLINE') }}:
          {{ statusBreakdown.offline }}
        </span>
      </div>

      <div
        v-if="isLoading"
        class="mt-4 grid auto-rows-[13rem] gap-3 grid-cols-1 sm:grid-cols-[repeat(auto-fit,minmax(17rem,21rem))] sm:justify-start"
      >
        <div
          v-for="index in 3"
          :key="`agent-skeleton-${index}`"
          class="min-h-[13rem] rounded-lg border border-dashed border-n-weak bg-n-alpha-3 animate-pulse"
        />
      </div>

      <div
        v-else-if="!agentList.length"
        class="mt-4 rounded-xl border border-n-weak bg-n-solid-1 px-6 py-10 text-center"
      >
        <h4 class="text-lg font-semibold text-n-slate-12">
          {{ t('MONITORING_REPORTS.AGENTS.EMPTY_TITLE') }}
        </h4>
        <p class="text-sm text-n-slate-11 mt-2">
          {{ t('MONITORING_REPORTS.AGENTS.EMPTY_MESSAGE') }}
        </p>
      </div>

      <div
        v-else
        class="mt-4 grid auto-rows-[13rem] gap-3 grid-cols-1 sm:grid-cols-[repeat(auto-fit,minmax(17rem,21rem))] sm:justify-start"
        data-testid="monitoring-agent-card"
      >
        <article
          v-for="agent in agentList"
          :key="agent.id"
          class="flex h-full flex-col overflow-hidden rounded-lg border border-n-weak bg-n-solid-1 px-4 py-4"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <h4 class="text-lg font-semibold text-n-slate-12 truncate">
                {{ agent.name }}
              </h4>
              <p class="text-xs text-n-slate-11 truncate">
                {{ agent.email }}
              </p>
            </div>
            <span
              class="inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-semibold"
              :class="
                availabilityTone[agent.availability_status] ||
                availabilityTone.offline
              "
            >
              <span class="size-2 rounded-full bg-current" />
              {{ statusLabel(agent.availability_status) }}
            </span>
          </div>

          <dl class="mt-4 grid flex-1 grid-cols-2 gap-3 text-sm">
            <div>
              <dt class="text-n-slate-11 line-clamp-1">
                {{ t('MONITORING_REPORTS.AGENTS.ACTIVE_CONVERSATIONS') }}
              </dt>
              <dd
                class="text-lg font-semibold tabular-nums"
                :class="
                  agent.active_conversations_count
                    ? 'text-n-slate-12'
                    : 'text-n-slate-11'
                "
              >
                {{ agent.active_conversations_count || 0 }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11 line-clamp-1">
                {{ t('MONITORING_REPORTS.AGENTS.INBOXES') }}
              </dt>
              <dd class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ agent.inboxes_count || 0 }}
              </dd>
            </div>
          </dl>

          <p class="mt-4 line-clamp-1 text-xs text-n-slate-11">
            {{ t('MONITORING_REPORTS.AGENTS.LAST_ACTIVITY') }}:
            <strong class="text-n-slate-12">
              {{ formatTimestamp(agent.last_activity_at) }}
            </strong>
          </p>
        </article>
      </div>
    </template>
  </section>
</template>
