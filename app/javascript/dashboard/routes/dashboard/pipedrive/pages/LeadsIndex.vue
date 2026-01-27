<script setup>
import { onMounted, computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute, useRouter } from 'vue-router';
import PipedriveListLayout from '../components/PipedriveListLayout.vue';
import LeadsList from '../components/LeadsList.vue';
import CreateLeadModal from '../components/modals/CreateLeadModal.vue';
import { useStorage } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
const router = useRouter();
const leads = useMapGetter('pipedrive/getLeads');
const meta = useMapGetter('pipedrive/getMeta');
const uiFlags = useMapGetter('pipedrive/getUIFlags');
const { t } = useI18n();

const activeFilter = ref([]);
const activeSort = ref('title');
const activeOrdering = ref('asc');
const savedFilterQuery = ref([]);
const searchQuery = useStorage('pipedrive-leads-search', '', sessionStorage);
const createModalRef = ref(null);

const currentPage = computed(() => {
  const leadsMeta = meta.value.leads || {};
  const start = leadsMeta.start || 0;
  const limit = leadsMeta.limit || 15;
  return Math.floor(start / limit) + 1;
});

const totalItems = computed(() => {
  const leadsMeta = meta.value.leads || {};
  if (Number.isInteger(leadsMeta.total)) return leadsMeta.total;

  const hasMore = leadsMeta.more_items_in_collection;
  const start = leadsMeta.start || 0;
  const currentLength = leads.value ? leads.value.length : 0;

  if (!hasMore) {
    return start + currentLength;
  }
  return start + currentLength + 1;
});

const filterId = computed(() => route.params.filterId);

const activeSegment = computed(() => {
  if (!filterId.value) return null;
  return store.getters['customViews/getPipedriveLeadsCustomViews'].find(
    v => String(v.id) === String(filterId.value)
  );
});

const headerTitle = computed(() =>
  activeSegment.value
    ? activeSegment.value.name
    : t('INTEGRATION_SETTINGS.PIPEDRIVE.LEADS')
);

// Fetch Logic
const fetchLeads = (page = 1, filters = null) => {
  const limit = 15;
  const start = (page - 1) * limit;
  const params = {
    start,
    limit,
    search: searchQuery.value,
    sort_by: activeSort.value,
    sort_direction: activeOrdering.value,
  };

  if (filters && (Array.isArray(filters) ? filters.length > 0 : filters)) {
    params.filters = filters;
  } else if (activeFilter.value && !Array.isArray(activeFilter.value)) {
    // Fallback for object-based filters if any
    params.filters = activeFilter.value;
  }

  store.dispatch('pipedrive/getLeads', params);
};

// Unified Context Controller
const fetchLeadsBasedOnContext = (page = 1) => {
  router.push({ query: { ...route.query, page } }).catch(() => {});

  let effectiveFilters = [];

  if (activeSegment.value) {
    effectiveFilters = activeSegment.value.query.payload || [];
    savedFilterQuery.value = effectiveFilters;
    // Sync local
    if (
      JSON.stringify(activeFilter.value) !== JSON.stringify(effectiveFilters)
    ) {
      activeFilter.value = effectiveFilters;
    }
  } else {
    // Standard / Manual
    savedFilterQuery.value = activeFilter.value || [];
    if (
      activeFilter.value &&
      (Array.isArray(activeFilter.value)
        ? activeFilter.value.length > 0
        : Object.keys(activeFilter.value).length > 0)
    ) {
      effectiveFilters = activeFilter.value;
    }
  }

  fetchLeads(page, effectiveFilters);
};

const onSearch = value => {
  searchQuery.value = value;
  fetchLeadsBasedOnContext(1);
};

const onFilter = filter => {
  activeFilter.value = filter;
  fetchLeadsBasedOnContext(1);
};

const onSort = ({ sort_by, sort_direction }) => {
  activeSort.value = sort_by;
  activeOrdering.value = sort_direction;
  fetchLeadsBasedOnContext(1);
};

const onCreate = () => {
  createModalRef.value.open();
};

watch(activeSegment, newSegment => {
  if (newSegment) {
    activeFilter.value = newSegment.query.payload || [];
  } else {
    activeFilter.value = [];
  }
  fetchLeadsBasedOnContext(1);
});

onMounted(() => {
  const page = Number(route.query.page) || 1;
  fetchLeadsBasedOnContext(page);
});
</script>

<template>
  <PipedriveListLayout
    resource-type="leads"
    :header-title="headerTitle"
    :active-segment-id="activeSegment?.id"
    :active-segment-name="activeSegment?.name"
    :button-label="$t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_LEAD')"
    :current-page="currentPage"
    :total-items="totalItems"
    :items-per-page="15"
    :is-fetching="uiFlags.isFetchingLeads"
    :active-status="activeFilter.archived_status"
    :saved-filter-query="savedFilterQuery"
    :search-value="searchQuery"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    @update:current-page="fetchLeadsBasedOnContext"
    @search="onSearch"
    @filter="onFilter"
    @sort="onSort"
    @click-action="onCreate"
  >
    <div v-if="uiFlags.isFetchingLeads" class="flex justify-center p-8">
      {{ $t('INTEGRATION_SETTINGS.LOADING') }}
    </div>
    <div v-else-if="uiFlags.error" class="text-red-500 p-8 text-center">
      {{ uiFlags.error }}
    </div>
    <LeadsList
      v-else
      :items="leads"
      @refresh="fetchLeadsBasedOnContext(currentPage)"
    />
  </PipedriveListLayout>
  <CreateLeadModal
    ref="createModalRef"
    @create="fetchLeadsBasedOnContext(1)"
  />
</template>
