<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  inboxes: {
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

const statusTone = {
  online: 'bg-n-teal-3 text-n-teal-11 border border-n-teal-4',
  warning: 'bg-n-amber-3 text-n-amber-11 border border-n-amber-4',
  offline: 'bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-4',
};

const statusCardTone = {
  online: 'border-n-teal-4',
  warning: 'border-n-amber-4',
  offline: 'border-n-ruby-4',
};

const channelLabel = channelType => {
  if (!channelType) {
    return 'Inbox';
  }
  const raw = channelType.split('::').pop();
  return raw.replace(/([a-z])([A-Z])/g, '$1 $2');
};

const formatTimestamp = isoString => {
  if (!isoString) {
    return t('MONITORING_REPORTS.INBOXES.NEVER');
  }
  return timeFormatter.value.format(new Date(isoString));
};

const statusLabel = status => {
  const key = status ? status.toUpperCase() : 'OFFLINE';
  return t(`MONITORING_REPORTS.STATUS.${key}`);
};

const statusBreakdown = computed(() => {
  const list = props.inboxes || [];
  return {
    total: list.length,
    online: list.filter(inbox => inbox.status === 'online').length,
    warning: list.filter(inbox => inbox.status === 'warning').length,
    offline: list.filter(inbox => inbox.status === 'offline').length,
  };
});
</script>

<template>
  <section
    class="shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2 px-6 py-5"
    data-testid="monitoring-inboxes"
  >
    <header class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h3 class="text-n-slate-12 font-medium text-lg mb-0">
          {{ t('MONITORING_REPORTS.INBOXES.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('MONITORING_REPORTS.INBOXES.SUBTITLE') }}
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
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-alpha-2 text-n-slate-12"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.TOTAL_INBOXES') }}:
          {{ statusBreakdown.total }}
        </span>
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-teal-3 text-n-teal-11 border border-n-teal-4"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.ONLINE_INBOXES') }}:
          {{ statusBreakdown.online }}
        </span>
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-amber-3 text-n-amber-11 border border-n-amber-4"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.WARNING_INBOXES') }}:
          {{ statusBreakdown.warning }}
        </span>
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 bg-n-ruby-3 text-n-ruby-11 border border-n-ruby-4"
        >
          {{ t('MONITORING_REPORTS.SUMMARY.OFFLINE_INBOXES') }}:
          {{ statusBreakdown.offline }}
        </span>
      </div>

      <div
        v-if="isLoading"
        class="mt-4 grid auto-rows-[18rem] gap-4 grid-cols-1 sm:grid-cols-[repeat(auto-fit,minmax(18rem,22rem))] sm:justify-start"
      >
        <div
          v-for="index in 3"
          :key="`inbox-skeleton-${index}`"
          class="min-h-[18rem] rounded-xl border border-dashed border-n-weak bg-n-alpha-3 animate-pulse"
        />
      </div>

      <div
        v-else-if="!inboxes.length"
        class="mt-4 rounded-xl border border-n-weak bg-n-solid-1 px-6 py-10 text-center"
      >
        <h4 class="text-lg font-semibold text-n-slate-12">
          {{ t('MONITORING_REPORTS.INBOXES.EMPTY_TITLE') }}
        </h4>
        <p class="text-sm text-n-slate-11 mt-2">
          {{ t('MONITORING_REPORTS.INBOXES.EMPTY_MESSAGE') }}
        </p>
      </div>

      <div
        v-else
        class="mt-4 grid auto-rows-[18rem] gap-4 grid-cols-1 sm:grid-cols-[repeat(auto-fit,minmax(18rem,22rem))] sm:justify-start"
        data-testid="monitoring-inbox-card"
      >
        <article
          v-for="inbox in inboxes"
          :key="inbox.id"
          class="flex h-full flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1 px-5 py-5"
          :class="[
            statusCardTone[inbox.status],
            {
              'outline outline-2 outline-n-amber-7': inbox.status === 'warning',
            },
          ]"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="text-xs uppercase tracking-wide text-n-slate-11">
                {{ channelLabel(inbox.channel_type) }}
              </p>
              <h4 class="text-lg font-semibold text-n-slate-12 truncate">
                {{ inbox.name }}
              </h4>
            </div>
            <span
              class="inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-semibold"
              :class="
                statusTone[inbox.status] ||
                'bg-n-alpha-2 text-n-slate-12 border border-n-weak'
              "
            >
              <span class="size-2 rounded-full bg-current" />
              {{ statusLabel(inbox.status) }}
            </span>
          </div>

          <dl class="mt-4 grid flex-1 grid-cols-2 gap-3 text-sm">
            <div>
              <dt class="text-n-slate-11 line-clamp-1">
                {{ t('MONITORING_REPORTS.INBOXES.ACTIVE') }}
              </dt>
              <dd class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ inbox.active_conversations_count || 0 }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11 line-clamp-1">
                {{ t('MONITORING_REPORTS.INBOXES.WAITING') }}
              </dt>
              <dd
                class="text-lg font-semibold"
                :class="
                  inbox.waiting_conversations_count
                    ? 'text-amber-400'
                    : 'text-n-slate-12'
                "
              >
                {{ inbox.waiting_conversations_count || 0 }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11 line-clamp-1">
                {{ t('MONITORING_REPORTS.INBOXES.UNASSIGNED') }}
              </dt>
              <dd class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ inbox.unassigned_conversations_count || 0 }}
              </dd>
            </div>
            <div>
              <dt class="text-n-slate-11 line-clamp-1">
                {{ t('MONITORING_REPORTS.INBOXES.AGENTS') }}
              </dt>
              <dd class="text-lg font-semibold text-n-slate-12 tabular-nums">
                {{ inbox.online_agents_count || 0 }} /
                {{ inbox.agents_count || 0 }}
              </dd>
            </div>
          </dl>

          <p class="mt-4 line-clamp-1 text-xs text-n-slate-11">
            {{ t('MONITORING_REPORTS.INBOXES.LAST_ACTIVITY') }}:
            <strong class="text-n-slate-12">{{
              formatTimestamp(inbox.last_activity_at)
            }}</strong>
          </p>
        </article>
      </div>
    </template>
  </section>
</template>
