<script setup>
import { onMounted, computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import PipedriveListLayout from '../components/PipedriveListLayout.vue';
import DealsList from '../components/DealsList.vue';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
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
const activeFilters = ref({});

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
  if (dealsMeta.total !== undefined) return dealsMeta.total;
  const start = dealsMeta.start || 0;
  const currentLength = deals.value ? deals.value.length : 0;
  return dealsMeta.more_items_in_collection ? start + currentLength + 1 : start + currentLength;
});

// Helper to extract value from filter payload (Simplified for Rich Payload)
const getValue = (filter, keyType = 'value') => {
  // keyType: 'value' (ID/Raw) or 'label' (Name)
  if (Array.isArray(filter)) {
    // Should not happen with new structure, but for safety:
    return filter.map(f => f[keyType]);
  }
  return filter[keyType];
};

// Methods
const fetchDeals = (page = 1) => {
  const limit = 15;
  const start = (page - 1) * limit;
  const params = {
    start,
    limit,
    search: searchQuery.value,
    sort_by: activeSort.value,
    sort_direction: activeOrdering.value,
  };

  // Apply filters if we have them (Rich Payload)
  if (Array.isArray(activeFilters.value) && activeFilters.value.length > 0) {
     params.filters = activeFilters.value;
  }
  
  // If no filters are active, and no specific status is requested in them, use the layout's active status if available
  // However, with rich payload, the status is usually inside the filters array.
  // We can leave 'status' param for legacy calls or if manually set outside filters
  if (!params.filters && activeStatus.value) {
    params.status = activeStatus.value;
  }

  store.dispatch('pipedrive/getDeals', params);
};


const initializeView = () => {
  // 1. Restore Search for context
  const contextKey = `pipedrive-deals-search-${filterId.value || 'all'}`;
  const storedSearch = sessionStorage.getItem(contextKey);
  searchQuery.value = storedSearch || '';

  // 2. Clear filters initially (will be populated if segment exists)
  savedFilterQuery.value = [];

  // 3. Reset Pagination & Fetch
  fetchDeals(1);
};

// Actions
const onSearch = value => {
  searchQuery.value = value;
  const contextKey = `pipedrive-deals-search-${filterId.value || 'all'}`;
  sessionStorage.setItem(contextKey, value);
  fetchDeals(1);
};

const onSort = ({ sort_by, sort_direction }) => {
  activeSort.value = sort_by;
  activeOrdering.value = sort_direction;
  fetchDeals(1);
};

const onFilter = payload => {
  activeFilters.value = payload;
  // Note: payload is an array, so payload.status check removed.
  // Status is now extracted inside fetchDeals.
  fetchDeals(1);
};

const onCreate = () => {
  // Implement creation logic
};

// Watchers
watch(
  filterId,
  () => {
    initializeView();
  },
  { immediate: true }
);

// When the segment data arrives (async) or changes, verify if we need to apply filters
watch(
  activeSegment,
  (newSegment, oldSegment) => {
    // Only apply if we are in a segment view
    if (filterId.value && newSegment && newSegment.query && newSegment.query.payload) {
       // Only update if it's different to avoid loops
       if (JSON.stringify(savedFilterQuery.value) !== JSON.stringify(newSegment.query.payload)) {
          savedFilterQuery.value = newSegment.query.payload;
       }
    }
  },
  { deep: true, immediate: true }
);

onMounted(() => {
  // Initial setup is handled by the immediate watch on filterId
});
</script>

<template>
  <PipedriveListLayout
    resource-type="deals"
    :header-title="headerTitle"
    :active-segment-id="activeSegment?.id"
    :active-segment-name="activeSegment?.name"
    button-label="Criar Negócio"
    :current-page="currentPage"
    :total-items="totalItems"
    :items-per-page="15"
    :is-fetching="uiFlags.isFetchingDeals"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    :active-status="activeStatus"
    :saved-filter-query="savedFilterQuery"
    :search-value="searchQuery"
    @update:current-page="fetchDeals"
    @search="onSearch"
    @sort="onSort"
    @filter="onFilter"
    @click-action="onCreate"
  >
    <div v-if="uiFlags.isFetchingDeals" class="flex justify-center p-8">
      {{ $t('INTEGRATION_SETTINGS.LOADING') }}
    </div>
    <div v-else-if="uiFlags.error" class="text-red-500 p-8 text-center">
      {{ uiFlags.error }}
    </div>
    <DealsList v-else :items="deals" />
  </PipedriveListLayout>
</template>
