<script setup>
import { onMounted, computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute, useRouter } from 'vue-router';
import PipedriveListLayout from '../components/PipedriveListLayout.vue';
import DealsList from '../components/DealsList.vue';
import CreateDealModal from '../components/modals/CreateDealModal.vue';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
const router = useRouter();
const deals = useMapGetter('pipedrive/getDeals');
const meta = useMapGetter('pipedrive/getMeta');
const uiFlags = useMapGetter('pipedrive/getUIFlags');
const { t } = useI18n();

// Local State
const activeSort = ref('add_time');
const activeOrdering = ref('desc');
const activeStatus = ref(null);
const searchQuery = ref('');
const savedFilterQuery = ref([]);
const activeFilters = ref([]);
const createModalRef = ref(null);

// Route & Segment
const filterId = computed(() => route.params.filterId);

const activeSegment = computed(() => {
  if (!filterId.value) return null;
  return store.getters['customViews/getPipedriveDealsCustomViews'].find(
    v => String(v.id) === String(filterId.value)
  );
});

const headerTitle = computed(() =>
  activeSegment.value
    ? activeSegment.value.name
    : t('INTEGRATION_SETTINGS.PIPEDRIVE.DEALS')
);

// Pagination
const currentPage = computed(() => {
  const dealsMeta = meta.value.deals || {};
  const start = dealsMeta.start || 0;
  const limit = dealsMeta.limit || 15;
  return Math.floor(start / limit) + 1;
});

const totalItems = computed(() => {
  const dealsMeta = meta.value.deals || {};
  if (Number.isInteger(dealsMeta.total)) return dealsMeta.total;
  const start = dealsMeta.start || 0;
  const currentLength = deals.value ? deals.value.length : 0;
  return dealsMeta.more_items_in_collection
    ? start + currentLength + 1
    : start + currentLength;
});

// Core Fetch Logic
const fetchDeals = (page = 1, filters = null) => {
  const limit = 15;
  const start = (page - 1) * limit;
  const params = {
    start,
    limit,
    search: searchQuery.value,
    sort_by: activeSort.value,
    sort_direction: activeOrdering.value,
  };

  if (filters && filters.length > 0) {
    params.filters = filters;
  } else if (activeStatus.value) {
    params.status = activeStatus.value;
  }

  store.dispatch('pipedrive/getDeals', params);
};

// Context Based Controller
const fetchDealsBasedOnContext = (page = 1) => {
  router.push({ query: { ...route.query, page } }).catch(() => {});

  let effectiveFilters = [];

  if (activeSegment.value) {
    effectiveFilters = activeSegment.value.query.payload || [];
    savedFilterQuery.value = effectiveFilters;
    // Ensure activeFilters matches segment for consistency
    if (
      JSON.stringify(activeFilters.value) !== JSON.stringify(effectiveFilters)
    ) {
      activeFilters.value = effectiveFilters;
    }
  } else {
    // Standard view or Manual Filter
    savedFilterQuery.value = activeFilters.value || [];
    if (activeFilters.value && activeFilters.value.length > 0) {
      effectiveFilters = activeFilters.value;
    }
  }

  fetchDeals(page, effectiveFilters);
};

// Actions
const onSearch = value => {
  searchQuery.value = value;
  const contextKey = `pipedrive-deals-search-${filterId.value || 'all'}`;
  sessionStorage.setItem(contextKey, value);
  fetchDealsBasedOnContext(1);
};

const onSort = ({ sort_by, sort_direction }) => {
  activeSort.value = sort_by;
  activeOrdering.value = sort_direction;
  fetchDealsBasedOnContext(1);
};

const onFilter = payload => {
  activeFilters.value = payload;
  fetchDealsBasedOnContext(1);
};

const onCreate = () => {
  createModalRef.value.open();
};

// Watchers
watch(activeSegment, newSegment => {
  if (newSegment) {
    // Entered Segment
    activeFilters.value = newSegment.query.payload || [];
  } else {
    // Exited Segment
    activeFilters.value = [];
  }

  fetchDealsBasedOnContext(1);
});

// Initial Setup
onMounted(() => {
  // Restore Search
  const contextKey = `pipedrive-deals-search-${filterId.value || 'all'}`;
  const storedSearch = sessionStorage.getItem(contextKey);
  if (storedSearch) {
    searchQuery.value = storedSearch;
  }

  // Initial Fetch logic
  const page = Number(route.query.page) || 1;
  fetchDealsBasedOnContext(page);
});
</script>

<template>
  <PipedriveListLayout
    resource-type="deals"
    :header-title="headerTitle"
    :active-segment-id="activeSegment?.id"
    :active-segment-name="activeSegment?.name"
    :button-label="$t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_DEAL')"
    :current-page="currentPage"
    :total-items="totalItems"
    :items-per-page="15"
    :is-fetching="uiFlags.isFetchingDeals"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    :active-status="activeStatus"
    :saved-filter-query="savedFilterQuery"
    :search-value="searchQuery"
    @update:current-page="fetchDealsBasedOnContext"
    @search="onSearch"
    @sort="onSort"
    @filter="onFilter"
    @click-action="onCreate"
  >
    <div v-if="uiFlags.isFetchingDeals" class="flex justify-center p-8">
      {{ $t('INTEGRATION_SETTINGS.LOADING') }}
    </div>
    <div v-else-if="uiFlags.error" class="p-8 flex flex-col items-center justify-center">
      <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative max-w-lg text-center" role="alert">
        <strong class="font-bold block mb-1">{{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.ERROR_TITLE') || 'Erro de Integração' }}</strong>
        <span class="block sm:inline">{{ uiFlags.error }}</span>
      </div>
    </div>
    <DealsList
      v-else
      :items="deals"
      @refresh="fetchDealsBasedOnContext(currentPage)"
    />
  </PipedriveListLayout>
  <CreateDealModal
    ref="createModalRef"
    @create="fetchDealsBasedOnContext(1)"
  />
</template>
