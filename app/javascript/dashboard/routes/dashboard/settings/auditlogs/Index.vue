<script setup>
import { useAlert } from 'dashboard/composables';
import { messageTimestamp } from 'shared/helpers/timeHelper';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import {
  generateTranslationPayload,
  generateLogActionKey,
} from 'dashboard/helper/auditlogHelper';
import { computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

const getters = useStoreGetters();
const store = useStore();
const router = useRouter();
const records = computed(() => getters['auditlogs/getAuditLogs'].value);
const uiFlags = computed(() => getters['auditlogs/getUIFlags'].value);
const meta = computed(() => getters['auditlogs/getMeta'].value);
const agentList = computed(() => getters['agents/getAgents'].value);

const { t } = useI18n();
const route = useRoute();

const routerPage = computed(() => Number(route.query.page ?? 1));

const fetchAuditLogs = page => {
  try {
    store.dispatch('auditlogs/fetch', { page });
  } catch (error) {
    const errorMessage = error?.message || t('AUDIT_LOGS.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

const generateLogText = auditLogItem => {
  const payload = generateTranslationPayload(auditLogItem, agentList.value);
  const translationKey = generateLogActionKey(auditLogItem);

  if (!translationKey) return '';

  const joinIfArray = value => {
    return Array.isArray(value) ? value.join(', ') : value;
  };

  const mergedPayload = {
    ...payload,
    attributes: joinIfArray(payload.attributes),
    values: joinIfArray(payload.values),
  };
  return t(translationKey, mergedPayload);
};

const hasValidLogText = auditLogItem => !!generateLogActionKey(auditLogItem);

const validRecords = computed(() => records.value.filter(hasValidLogText));

const onPageChange = page => {
  router.push({ name: 'auditlogs_list', query: { page: page } });
};

onMounted(() => {
  store.dispatch('agents/get');
  fetchAuditLogs(routerPage.value);
});

watch(routerPage, (newPage, oldPage) => {
  if (newPage !== oldPage) {
    fetchAuditLogs(newPage);
  }
});

const tableHeaders = computed(() => {
  return [
    t('AUDIT_LOGS.LIST.TABLE_HEADER.ACTIVITY'),
    t('AUDIT_LOGS.LIST.TABLE_HEADER.TIME'),
    t('AUDIT_LOGS.LIST.TABLE_HEADER.IP_ADDRESS'),
  ];
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="$t('AUDIT_LOGS.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('AUDIT_LOGS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AUDIT_LOGS.HEADER')"
        :description="$t('AUDIT_LOGS.DESCRIPTION')"
        :link-text="$t('AUDIT_LOGS.LEARN_MORE')"
        feature-name="audit_logs"
      />
      <p
        v-if="!uiFlags.fetchingList && !validRecords.length"
        class="flex flex-col items-center justify-center h-full text-base p-8"
      >
        {{ $t('AUDIT_LOGS.LIST.404') }}
      </p>
      <div v-else-if="!uiFlags.fetchingList" class="min-w-full overflow-x-auto">
        <table class="divide-y divide-n-weak">
          <thead>
            <th
              v-for="thHeader in tableHeaders"
              :key="thHeader"
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ thHeader }}
            </th>
          </thead>
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="auditLogItem in validRecords" :key="auditLogItem.id">
              <td class="py-4 ltr:pr-4 rtl:pl-4 break-all whitespace-nowrap">
                {{ generateLogText(auditLogItem) }}
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4 break-all whitespace-nowrap">
                {{
                  messageTimestamp(
                    auditLogItem.created_at,
                    'MMM dd, yyyy hh:mm a'
                  )
                }}
              </td>
              <td class="py-4 w-[8.75rem]">
                {{ auditLogItem.remote_address }}
              </td>
            </tr>
          </tbody>
        </table>
        <PaginationFooter
          :current-page="Number(meta.currentPage)"
          :total-items="meta.totalEntries"
          :items-per-page="meta.perPage"
          class="!px-0"
          @update:current-page="onPageChange"
        />
      </div>
    </template>
  </SettingsLayout>
</template>
