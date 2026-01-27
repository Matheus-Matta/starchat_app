<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useDebounceFn } from '@vueuse/core';

import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ActiveFilterPreview from 'dashboard/components-next/filter/ActiveFilterPreview.vue';
import CreateSegmentDialog from 'dashboard/components-next/Contacts/ContactsForm/CreateSegmentDialog.vue';
import DeleteSegmentDialog from 'dashboard/components-next/Contacts/ContactsForm/DeleteSegmentDialog.vue';
import PipedriveSortMenu from './PipedriveSortMenu.vue';
import PipedriveFilter from './PipedriveFilter.vue';

const props = defineProps({
  headerTitle: { type: String, default: '' },
  showPaginationFooter: { type: Boolean, default: true },
  currentPage: { type: Number, default: 1 },
  totalItems: { type: Number, default: 0 },
  itemsPerPage: { type: Number, default: 15 },
  searchValue: { type: String, default: '' },
  buttonLabel: { type: String, default: 'Criar' },
  resourceType: { type: String, default: 'deals' },
  activeSort: { type: String, default: '' },
  activeOrdering: { type: String, default: '' },
  savedFilterQuery: { type: Array, default: () => [] },
  activeSegmentId: { type: [String, Number], default: null },
  activeSegmentName: { type: String, default: '' },
});

const emit = defineEmits([
  'update:currentPage',
  'search',
  'click-action',
  'sort',
  'filter',
]);

const SEARCH_DEBOUNCE_MS = 800;
const FILTER_TYPE_MAP = {
  deals: 3,
  leads: 4,
  activities: 5,
};
const ROUTE_NAMES = {
  deals: {
    index: 'pipedrive_deals_index',
    filters: 'pipedrive_deals_filters',
  },
  leads: {
    index: 'pipedrive_leads_index',
    filters: 'pipedrive_leads_filters',
  },
  activities: {
    index: 'pipedrive_activities_index',
    filters: 'pipedrive_activities_filters',
  },
};

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const activeFilters = ref([]);
const filterRef = ref(null);
const createSegmentDialogRef = ref(null);
const deleteSegmentDialogRef = ref(null);
const showFilterModal = ref(false);

watch(
  () => props.savedFilterQuery,
  newVal => {
    activeFilters.value = newVal || [];
  },
  { immediate: true }
);

const updateCurrentPage = page => {
  emit('update:currentPage', page);
};

const onSearchInput = useDebounceFn(value => {
  emit('search', value);
}, SEARCH_DEBOUNCE_MS);

const onUpdateAppliedFilters = async filters => {
  activeFilters.value = filters;
  emit('filter', filters);
  showFilterModal.value = false;
};

const clearAllFilters = async () => {
  filterRef.value?.reset();
  activeFilters.value = [];
  emit('filter', []);
};

const openFilter = () => {
  showFilterModal.value = true;
};

const closeFilter = () => {
  showFilterModal.value = false;
};

const openCreateSegmentDialog = () => {
  const config = props.activeSegmentId
    ? { name: props.activeSegmentName, edit: true }
    : undefined;

  createSegmentDialogRef.value?.open(config);
};

const currentFilterType = computed(
  () => FILTER_TYPE_MAP[props.resourceType] || FILTER_TYPE_MAP.deals
);

const buildSegmentPayload = name => ({
  name,
  filter_type: currentFilterType.value,
  query: { payload: activeFilters.value },
});

const navigateToFilter = filterId => {
  const routeName =
    ROUTE_NAMES[props.resourceType]?.filters || ROUTE_NAMES.deals.filters;

  router.push({
    name: routeName,
    params: {
      accountId: router.currentRoute.value.params.accountId,
      filterId,
    },
  });
};

const onCreateSegment = async ({ name }) => {
  const payloadData = buildSegmentPayload(name);

  try {
    if (props.activeSegmentId) {
      await store.dispatch('customViews/update', {
        id: props.activeSegmentId,
        ...payloadData,
      });
      useAlert(
        t(
          'CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.UPDATE_SEGMENT.SUCCESS_MESSAGE'
        )
      );
    } else {
      const result = await store.dispatch('customViews/create', payloadData);
      useAlert(
        t(
          'CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.SUCCESS_MESSAGE'
        )
      );

      if (result?.data?.id) {
        navigateToFilter(result.data.id);
      }
    }
  } catch (error) {
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.ERROR_MESSAGE')
    );
  }
};

const confirmDeleteSegment = () => {
  deleteSegmentDialogRef.value?.dialogRef.open();
};

const navigateToIndex = () => {
  const routeName =
    ROUTE_NAMES[props.resourceType]?.index || ROUTE_NAMES.deals.index;

  router.push({
    name: routeName,
    params: { accountId: router.currentRoute.value.params.accountId },
  });
};

const onDeleteSegment = async () => {
  try {
    await store.dispatch('customViews/delete', {
      id: props.activeSegmentId,
      filterType: currentFilterType.value,
    });
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.DELETE_SEGMENT.SUCCESS_MESSAGE')
    );
    deleteSegmentDialogRef.value?.dialogRef.close();
    navigateToIndex();
  } catch (error) {
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.DELETE_SEGMENT.ERROR_MESSAGE')
    );
  }
};

const paginationInfoKey = computed(() => {
  const keys = {
    deals: 'INTEGRATION_SETTINGS.PIPEDRIVE.PAGINATION.SHOWING_DEALS',
    leads: 'INTEGRATION_SETTINGS.PIPEDRIVE.PAGINATION.SHOWING_LEADS',
    activities: 'INTEGRATION_SETTINGS.PIPEDRIVE.PAGINATION.SHOWING_ACTIVITIES',
  };
  return (
    keys[props.resourceType] || 'CONTACTS_LAYOUT.PAGINATION_FOOTER.SHOWING'
  );
});
</script>

<template>
  <section
    class="flex w-full h-full gap-4 overflow-hidden justify-evenly bg-n-background"
  >
    <div class="flex flex-col w-full h-full transition-all duration-300">
      <header class="sticky top-0 z-10">
        <div
          class="flex items-start sm:items-center justify-between w-full py-6 px-6 gap-2 mx-auto max-w-[60rem]"
        >
          <span class="text-xl font-medium truncate text-n-slate-12">
            {{ headerTitle }}
          </span>
          <div
            class="flex items-center flex-col sm:flex-row flex-shrink-0 gap-4"
          >
            <div v-if="!activeSegmentId" class="flex items-center gap-2 w-full">
              <Input
                :model-value="searchValue"
                type="search"
                placeholder="Pesquisar..."
                custom-input-class="h-8 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-8 !py-1 rtl:!pr-8"
                class="w-full"
                @input="onSearchInput($event.target.value)"
              >
                <template #prefix>
                  <Icon
                    icon="i-lucide-search"
                    class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-2 rtl:right-2"
                  />
                </template>
              </Input>
            </div>
            <div class="flex items-center gap-2">
              <div v-if="!activeSegmentId" class="relative">
                <Button
                  id="pipedrive-filter-button"
                  icon="i-lucide-list-filter"
                  color="slate"
                  size="sm"
                  variant="ghost"
                  class="relative w-8"
                  @click="openFilter"
                >
                  <div
                    v-if="activeFilters.length > 0"
                    class="absolute top-0 right-0 w-2 h-2 rounded-full bg-n-brand"
                  />
                </Button>
                <PipedriveFilter
                  v-if="showFilterModal"
                  ref="filterRef"
                  v-model="activeFilters"
                  :resource-type="resourceType"
                  class="absolute mt-1 ltr:right-0 rtl:left-0 top-full"
                  @update:applied-filters="onUpdateAppliedFilters"
                  @close="closeFilter"
                />
              </div>
              <div class="relative">
                <Button
                  v-if="activeSegmentId"
                  icon="i-lucide-pen-line"
                  color="slate"
                  size="sm"
                  variant="ghost"
                  @click="openCreateSegmentDialog"
                />
                <Button
                  v-else-if="activeFilters.length > 0"
                  icon="i-lucide-save"
                  color="slate"
                  size="sm"
                  variant="ghost"
                  @click="openCreateSegmentDialog"
                />
              </div>
              <Button
                v-if="activeSegmentId"
                icon="i-lucide-trash"
                color="slate"
                size="sm"
                variant="ghost"
                @click="confirmDeleteSegment"
              />
              <div class="relative">
                <PipedriveSortMenu
                  :resource-type="resourceType"
                  :active-sort="activeSort"
                  :active-ordering="activeOrdering"
                  @update:sort="emit('sort', $event)"
                />
              </div>
            </div>
            <slot name="header-actions" />
            <div class="w-px h-4 bg-n-strong" />
            <Button
              :label="buttonLabel"
              size="sm"
              class="min-w-[140px]"
              @click="emit('click-action')"
            />
          </div>
        </div>
      </header>

      <main class="flex-1 overflow-y-auto">
        <div class="w-full mx-auto max-w-[60rem] px-6 py-6">
          <ActiveFilterPreview
            v-if="activeFilters.length > 0"
            :applied-filters="activeFilters"
            :max-visible-filters="2"
            :more-filters-label="
              t('CONTACTS_LAYOUT.FILTER.ACTIVE_FILTERS.MORE_FILTERS', {
                count: activeFilters.length - 2,
              })
            "
            :clear-button-label="
              t('CONTACTS_LAYOUT.FILTER.ACTIVE_FILTERS.CLEAR_FILTERS')
            "
            :show-clear-button="!activeSegmentId"
            class="mb-6"
            @open-filter="openFilter"
            @clear-filters="clearAllFilters"
          />
          <slot name="default" />
        </div>
      </main>
      <footer v-if="showPaginationFooter" class="sticky bottom-0 z-0 px-4 pb-4">
        <PaginationFooter
          :current-page-info="paginationInfoKey"
          :current-page="currentPage"
          :total-items="totalItems"
          :items-per-page="itemsPerPage"
          @update:current-page="updateCurrentPage"
        />
      </footer>
    </div>

    <CreateSegmentDialog
      ref="createSegmentDialogRef"
      :filter-type="currentFilterType"
      @create="onCreateSegment"
    />
    <DeleteSegmentDialog
      ref="deleteSegmentDialogRef"
      @delete="onDeleteSegment"
    />
  </section>
</template>
