<script setup>
import { onMounted, computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import PipedriveListLayout from '../components/PipedriveListLayout.vue';
import ActivitiesList from '../components/ActivitiesList.vue';
import { useStorage } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
const activities = useMapGetter('pipedrive/getActivities');
const meta = useMapGetter('pipedrive/getMeta');
const uiFlags = useMapGetter('pipedrive/getUIFlags');
const { t } = useI18n();

const activeFilter = ref({});
const searchQuery = useStorage(
  'pipedrive-activities-search',
  '',
  sessionStorage
);
const activeSort = ref('due_date'); // Default sort field for activities? Pipedrive default might be due_date or add_time
const activeOrdering = ref('asc');
const savedFilterQuery = ref([]);

const currentPage = computed(() => {
  const activitiesMeta = meta.value.activities || {};
  const start = activitiesMeta.start || 0;
  const limit = activitiesMeta.limit || 15;
  return Math.floor(start / limit) + 1;
});

const totalItems = computed(() => {
  const activitiesMeta = meta.value.activities || {};
  if (activitiesMeta.total !== undefined) return activitiesMeta.total;

  const hasMore = activitiesMeta.more_items_in_collection;
  const start = activitiesMeta.start || 0;
  // activities is "items" prop passed to Layout, but here accessed via getter.
  const currentLength = activities.value ? activities.value.length : 0;

  if (!hasMore) {
    return start + currentLength;
  }
  return start + currentLength + 1;
});

const filterId = computed(() => route.params.filterId);

const activeSegment = computed(() => {
  if (!filterId.value) return null;
  return store.getters['customViews/getPipedriveActivitiesCustomViews'].find(
    v => String(v.id) === String(filterId.value)
  );
});

const headerTitle = computed(() =>
  activeSegment.value
    ? activeSegment.value.name
    : t('INTEGRATION_SETTINGS.PIPEDRIVE.ACTIVITIES')
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

const fetchActivities = (page = 1) => {
  const limit = 15;
  const start = (page - 1) * limit;
  const params = {
    start,
    limit,
    // If it's an array (Rich Payload)
    ...(Array.isArray(activeFilter.value) ? { filters: activeFilter.value } : activeFilter.value),
    search: searchQuery.value,
    sort_by: activeSort.value,
    sort_direction: activeOrdering.value,
  };
  store.dispatch('pipedrive/getActivities', params);
};

const onSearch = value => {
  searchQuery.value = value;
  fetchActivities(1);
};

const onFilter = filter => {
  activeFilter.value = filter;
  fetchActivities(1);
};

const onSort = ({ sort_by, sort_direction }) => {
  activeSort.value = sort_by;
  activeOrdering.value = sort_direction;
  fetchActivities(1);
};

const onCreate = () => {
  // Implement creation logic
};

onMounted(() => {
  fetchActivities(1);
});
</script>

<template>
  <PipedriveListLayout
    resource-type="activities"
    :header-title="headerTitle"
    :active-segment-id="activeSegment?.id"
    :active-segment-name="activeSegment?.name"
    button-label="Criar Atividade"
    :current-page="currentPage"
    :total-items="totalItems"
    :is-fetching="uiFlags.isFetchingActivities"
    :active-status="activeFilter.done"
    :saved-filter-query="savedFilterQuery"
    :search-value="searchQuery"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    :items-per-page="15"
    @update:current-page="fetchActivities"
    @search="onSearch"
    @filter="onFilter"
    @sort="onSort"
    @click-action="onCreate"
  >
    <div v-if="uiFlags.isFetchingActivities" class="flex justify-center p-8">
      {{ $t('INTEGRATION_SETTINGS.LOADING') }}
    </div>
    <div v-else-if="uiFlags.error" class="text-red-500 p-8 text-center">
      {{ uiFlags.error }}
    </div>
    <ActivitiesList v-else :items="activities" />
  </PipedriveListLayout>
</template>
