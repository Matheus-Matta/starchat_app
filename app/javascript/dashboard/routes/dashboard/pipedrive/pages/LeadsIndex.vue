<script setup>
import { onMounted, computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import PipedriveListLayout from '../components/PipedriveListLayout.vue';
import LeadsList from '../components/LeadsList.vue';
import { useStorage } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
const leads = useMapGetter('pipedrive/getLeads');
const meta = useMapGetter('pipedrive/getMeta');
const uiFlags = useMapGetter('pipedrive/getUIFlags');
const { t } = useI18n();

const activeFilter = ref({});
const activeSort = ref('title');
const activeOrdering = ref('asc');
const savedFilterQuery = ref([]);
const searchQuery = useStorage('pipedrive-leads-search', '', sessionStorage);

const currentPage = computed(() => {
  const leadsMeta = meta.value.leads || {};
  const start = leadsMeta.start || 0;
  const limit = leadsMeta.limit || 15;
  return Math.floor(start / limit) + 1;
});

const totalItems = computed(() => {
  const activitiesMeta = meta.value.activities || {};
  if (activitiesMeta.total !== undefined) return activitiesMeta.total;

  const hasMore = activitiesMeta.more_items_in_collection;
  const start = activitiesMeta.start || 0;
  // activities is "items" prop passed to Layout, but here accessed via getter.
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

watch(
  activeSegment,
  segment => {
    if (segment && segment.query && segment.query.payload) {
      savedFilterQuery.value = segment.query.payload;
    } else if (!filterId.value) {
      savedFilterQuery.value = [];
    }
  },
  { immediate: true }
);

const fetchLeads = (page = 1) => {
  const limit = 15;
  const start = (page - 1) * limit;
  const params = {
    start,
    limit,
    // If it's an array (Rich Payload)
    ...(Array.isArray(activeFilter.value) ? { filters: activeFilter.value } : activeFilter.value), // Fallback if it is somehow an object
    search: searchQuery.value,
    sort_by: activeSort.value,
    sort_direction: activeOrdering.value,
  };
  store.dispatch('pipedrive/getLeads', params);
};

const onSearch = value => {
  searchQuery.value = value;
  fetchLeads(1);
};

const onFilter = filter => {
  activeFilter.value = filter;
  fetchLeads(1);
};

const onSort = ({ sort_by, sort_direction }) => {
  activeSort.value = sort_by;
  activeOrdering.value = sort_direction;
  fetchLeads(1);
};

const onCreate = () => {
  // Implement creation logic
};

onMounted(() => {
  fetchLeads(1);
});
</script>

<template>
  <PipedriveListLayout
    resource-type="leads"
    :header-title="headerTitle"
    :active-segment-id="activeSegment?.id"
    :active-segment-name="activeSegment?.name"
    button-label="Criar Lead"
    :current-page="currentPage"
    :total-items="totalItems"
    :items-per-page="15"
    :is-fetching="uiFlags.isFetchingLeads"
    :active-status="activeFilter.archived_status"
    :saved-filter-query="savedFilterQuery"
    :search-value="searchQuery"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    @update:current-page="updateCurrentPage"
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
    <LeadsList v-else :items="leads" />
  </PipedriveListLayout>
</template>
