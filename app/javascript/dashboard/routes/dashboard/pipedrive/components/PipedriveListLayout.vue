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
  isFetching: { type: Boolean, default: false },
  searchValue: { type: String, default: '' },
  buttonLabel: { type: String, default: 'Criar' },
  resourceType: { type: String, default: 'deals' },
  activeSort: { type: String, default: '' },
  activeOrdering: { type: String, default: '' },
  activeStatus: { type: String, default: '' },
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

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const activeFilters = ref([]);
const filterRef = ref(null);
const createSegmentDialogRef = ref(null);

const isInternalFilterUpdate = ref(false);

watch(
  () => props.savedFilterQuery,
  newVal => {
    isInternalFilterUpdate.value = true; // Prevent auto-saving segment during load
    
    // Use setTimeout to allow component to mount/update if needed
    setTimeout(() => {
      if (filterRef.value) {
        if (newVal && newVal.length > 0) {
          filterRef.value.setFilters(newVal);
        } else {
          filterRef.value.reset();
          activeFilters.value = [];
        }
      }
      
      // Release the lock after a short delay to ensure all events propagated
      setTimeout(() => {
        isInternalFilterUpdate.value = false;
      }, 300);
    }, 100);
  },
  { immediate: true }
);

const updateCurrentPage = page => {
  emit('update:currentPage', page);
};

const onSearchInput = useDebounceFn(value => {
  emit('search', value);
}, 800);

const onUpdateAppliedFilters = async filters => {
  activeFilters.value = filters;
  emit('filter', filters);

  if (props.activeSegmentId && !isInternalFilterUpdate.value) {
    try {
      await store.dispatch('customViews/update', {
        id: props.activeSegmentId,
        name: props.activeSegmentName,
        query: { payload: filters },
      });
      useAlert(
        t(
          'CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.UPDATE_SEGMENT.SUCCESS_MESSAGE'
        )
      );
    } catch (error) {
      useAlert(
        t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.ERROR_MESSAGE')
      );
    }
  } else {
  }
};

const clearAllFilters = async () => {
  if (filterRef.value) {
    isInternalFilterUpdate.value = true;
    
    filterRef.value.reset();
    isInternalFilterUpdate.value = false; // Reset immediately after sync reset call
  }
  activeFilters.value = [];
  emit('filter', []);
};


const openFilter = () => {
  filterRef.value?.open();
};

const openCreateSegmentDialog = () => {
  if (props.activeSegmentId) {
    createSegmentDialogRef.value?.open({
      name: props.activeSegmentName,
      edit: true,
    });
  } else {
    createSegmentDialogRef.value?.open();
  }
};

const filterTypeMap = {
  deals: 3, // pipedrive_deals
  leads: 4, // pipedrive_leads
  activities: 5, // pipedrive_activities
};

const currentFilterType = computed(
  () => filterTypeMap[props.resourceType] || 3
);

const onCreateSegment = async ({ name, filter_type }) => {
  const payloadData = {
    name,
    filter_type,
    query: { payload: activeFilters.value },
  };

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
      if (result && result.data && result.data.id) {
        let routeName = 'pipedrive_deals_filters';
        if (props.resourceType === 'leads')
          routeName = 'pipedrive_leads_filters';
        if (props.resourceType === 'activities')
          routeName = 'pipedrive_activities_filters';

        router.push({
          name: routeName,
          params: {
            accountId: router.currentRoute.value.params.accountId,
            filterId: result.data.id,
          },
        });
      }
    }
  } catch (error) {
    useAlert(
      t('CONTACTS_LAYOUT.HEADER.ACTIONS.FILTERS.CREATE_SEGMENT.ERROR_MESSAGE')
    );
  }
};

const deleteSegmentDialogRef = ref(null);

const confirmDeleteSegment = () => {
  deleteSegmentDialogRef.value?.dialogRef.open();
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
    router.push({
      name:
        props.resourceType === 'leads'
          ? 'pipedrive_leads_index'
          : props.resourceType === 'activities'
            ? 'pipedrive_activities_index'
            : 'pipedrive_deals_index',
      params: { accountId: router.currentRoute.value.params.accountId },
    });
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
              </div>
              <PipedriveFilter
                v-if="!activeSegmentId"
                ref="filterRef"
                :resource-type="resourceType"
                :active-status="activeStatus"
                @update:applied-filters="onUpdateAppliedFilters"
              />
              <div class="flex items-center gap-2">
                 <Button
                    v-if="!activeSegmentId"
                    icon="i-lucide-filter"
                    size="sm"
                    variant="ghost"
                    @click="openFilter"
                 />
                 <div class="relative">
                  <button
                    v-if="activeSegmentId"
                    id="toggleContactsFilterButton"
                    class="relative w-8 inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline disabled:opacity-50 text-n-slate-12 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent h-8 px-3 text-sm active:enabled:scale-[0.97] justify-center"
                    @click="openCreateSegmentDialog"
                  >
                    <span class="i-lucide-pen-line flex-shrink-0" />
                  </button>
                  <Button
                    v-else-if="activeFilters.length > 0"
                    icon="i-lucide-save"
                    size="sm"
                    variant="ghost"
                    @click="openCreateSegmentDialog"
                  />
                </div>
                <!--v-if-->
                <button
                  v-if="activeSegmentId"
                  class="inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline disabled:opacity-50 text-n-slate-12 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent h-8 w-8 p-0 text-sm active:enabled:scale-[0.97] justify-center"
                  @click="confirmDeleteSegment"
                >
                  <span class="i-lucide-trash flex-shrink-0" />
                  <!--v-if-->
                  <!--v-if-->
                </button>
                <div class="relative">
                  <PipedriveSortMenu
                    :resource-type="resourceType"
                    :active-sort="activeSort"
                    :active-ordering="activeOrdering"
                    @update:sort="emit('sort', $event)"
                  >
                    <template #trigger>
                      <button
                        class="inline-flex items-center min-w-0 gap-2 transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline disabled:opacity-50 text-n-slate-12 hover:enabled:bg-n-alpha-2 focus-visible:bg-n-alpha-2 outline-transparent h-8 w-8 p-0 text-sm active:enabled:scale-[0.97] justify-center"
                      >
                        <span class="i-lucide-arrow-down-up flex-shrink-0" />
                        <!--v-if-->
                        <!--v-if-->
                      </button>
                    </template>
                  </PipedriveSortMenu>
                  <!--v-if-->
                </div>
              </div>
              <slot name="header-actions" />
              <div class="w-px h-4 bg-n-strong" />
              <Button
                :label="buttonLabel"
                size="sm"
                @click="emit('click-action')"
              />
            </div>
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
