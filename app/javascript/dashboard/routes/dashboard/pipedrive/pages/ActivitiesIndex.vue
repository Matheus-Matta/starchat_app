<script setup>
import { onMounted, computed, ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute, useRouter } from 'vue-router';
import PipedriveListLayout from '../components/PipedriveListLayout.vue';
import ActivitiesList from '../components/ActivitiesList.vue';
import CreateActivityModal from '../components/modals/CreateActivityModal.vue';
import { useStorage } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

const store = useStore();
const route = useRoute();
const router = useRouter();
const activities = useMapGetter('pipedrive/getActivities');
const meta = useMapGetter('pipedrive/getMeta');
const uiFlags = useMapGetter('pipedrive/getUIFlags');
const { t } = useI18n();

const activeFilter = ref([]);
const searchQuery = useStorage(
  'pipedrive-activities-search',
  '',
  sessionStorage
);
const activeSort = ref('due_date');
const activeOrdering = ref('asc');
const savedFilterQuery = ref([]);
const createModalRef = ref(null);

const currentPage = computed(() => {
  const activitiesMeta = meta.value.activities || {};
  const start = activitiesMeta.start || 0;
  const limit = activitiesMeta.limit || 15;
  return Math.floor(start / limit) + 1;
});

const totalItems = computed(() => {
  const activitiesMeta = meta.value.activities || {};
  if (Number.isInteger(activitiesMeta.total)) return activitiesMeta.total;

  const hasMore = activitiesMeta.more_items_in_collection;
  const start = activitiesMeta.start || 0;
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

// Fetch Logic
const fetchActivities = (page = 1, filters = null) => {
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
    // Fallback
    params.filters = activeFilter.value;
  }

  store.dispatch('pipedrive/getActivities', params);
};

// Unified Controller
const fetchActivitiesBasedOnContext = (page = 1) => {
  router.push({ query: { ...route.query, page } }).catch(() => {});

  let effectiveFilters = [];

  if (activeSegment.value) {
    effectiveFilters = activeSegment.value.query.payload || [];
    savedFilterQuery.value = effectiveFilters;
    if (
      JSON.stringify(activeFilter.value) !== JSON.stringify(effectiveFilters)
    ) {
      activeFilter.value = effectiveFilters;
    }
  } else {
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

  fetchActivities(page, effectiveFilters);
};

const onSearch = value => {
  searchQuery.value = value;
  fetchActivitiesBasedOnContext(1);
};

const onFilter = filter => {
  activeFilter.value = filter;
  fetchActivitiesBasedOnContext(1);
};

const onSort = ({ sort_by, sort_direction }) => {
  activeSort.value = sort_by;
  activeOrdering.value = sort_direction;
  fetchActivitiesBasedOnContext(1);
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
  fetchActivitiesBasedOnContext(1);
});

onMounted(() => {
  const page = Number(route.query.page) || 1;
  fetchActivitiesBasedOnContext(page);
});
</script>

<template>
  <PipedriveListLayout
    resource-type="activities"
    :header-title="headerTitle"
    :active-segment-id="activeSegment?.id"
    :active-segment-name="activeSegment?.name"
    :button-label="$t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_ACTIVITY')"
    :current-page="currentPage"
    :total-items="totalItems"
    :is-fetching="uiFlags.isFetchingActivities"
    :active-status="activeFilter.done"
    :saved-filter-query="savedFilterQuery"
    :search-value="searchQuery"
    :active-sort="activeSort"
    :active-ordering="activeOrdering"
    :items-per-page="15"
    @update:current-page="fetchActivitiesBasedOnContext"
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
    <ActivitiesList
      v-else
      :items="activities"
      @refresh="fetchActivitiesBasedOnContext(currentPage)"
    />
  </PipedriveListLayout>
  <CreateActivityModal
    ref="createModalRef"
    @create="fetchActivitiesBasedOnContext(1)"
  />
</template>
