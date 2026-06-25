<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import {
  buildFilterList,
  getActiveFilter,
  getFilterType,
} from './helpers/SLAFilterHelpers';
import {
  parseFilterURLParams,
  generateCompleteURLParams,
} from '../../helpers/reportFilterHelper';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import ActiveFilterChip from '../Filters/v3/ActiveFilterChip.vue';
import AddFilterChip from '../Filters/v3/AddFilterChip.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const emit = defineEmits(['filterChange']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

// Filter types that support selecting more than one value at once.
// sla_policy_id stays single-select (it's a single policy configuration, not
// an entity to combine/compare).
const MULTI_KEYS = ['assigned_agent_id', 'inbox_id', 'team_id', 'label_list'];

const showDropdownMenu = ref(false);
const showSubDropdownMenu = ref(false);
const activeFilterType = ref('');
const appliedFilters = ref({
  assigned_agent_id: [],
  inbox_id: [],
  team_id: [],
  sla_policy_id: null,
  label_list: [],
});

const isFilterActive = value =>
  Array.isArray(value) ? value.length > 0 : !!value;

const agents = computed(() => store.getters['agents/getAgents']);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const teams = computed(() => store.getters['teams/getTeams']);
const labels = computed(() => store.getters['labels/getLabels']);
const sla = computed(() => store.getters['sla/getSLA']);

const filterSources = computed(() => ({
  agents: agents.value,
  inboxes: inboxes.value,
  teams: teams.value,
  labels: labels.value,
  sla: sla.value,
}));

// Labels are stored/matched by title rather than numeric id (cached_label_list
// is a text match), so the option's "id" is normalized to its title here to
// keep the generic multi-select logic (matching by `id`) consistent.
const getFilterOptions = type => {
  const list = buildFilterList(filterSources.value[type], type);
  return type === 'labels'
    ? list.map(item => ({ ...item, id: item.name }))
    : list;
};

const filterListMenuItems = computed(() => {
  const filterTypes = [
    { id: '1', name: t('SLA_REPORTS.DROPDOWN.SLA'), type: 'sla' },
    { id: '2', name: t('SLA_REPORTS.DROPDOWN.INBOXES'), type: 'inboxes' },
    { id: '3', name: t('SLA_REPORTS.DROPDOWN.AGENTS'), type: 'agents' },
    { id: '4', name: t('SLA_REPORTS.DROPDOWN.TEAMS'), type: 'teams' },
    { id: '5', name: t('SLA_REPORTS.DROPDOWN.LABELS'), type: 'labels' },
  ];

  const activeFilterKeys = Object.keys(appliedFilters.value).filter(key =>
    isFilterActive(appliedFilters.value[key])
  );
  const activeFilterTypes = activeFilterKeys.map(key =>
    getFilterType(key, 'keyToType')
  );

  return filterTypes
    .filter(({ type }) => !activeFilterTypes.includes(type))
    .map(({ id, name, type }) => ({
      id,
      name,
      type,
      options: getFilterOptions(type),
    }));
});

// One chip per active filter type. Agents/inboxes/teams/labels render as a
// multi-select combobox (isMulti: true) so several values can be combined;
// the SLA policy filter stays single-select.
const activeFilters = computed(() => {
  const activeKeys = Object.keys(appliedFilters.value).filter(key =>
    isFilterActive(appliedFilters.value[key])
  );

  return activeKeys.map(key => {
    const filterType = getFilterType(key, 'keyToType');
    const options = getFilterOptions(filterType);

    if (MULTI_KEYS.includes(key)) {
      return {
        type: filterType,
        isMulti: true,
        selectedIds: appliedFilters.value[key],
        options: options.map(item => ({ value: item.id, label: item.name })),
      };
    }

    const item = getActiveFilter(
      filterSources.value[filterType],
      filterType,
      appliedFilters.value[key]
    );
    return {
      id: item.id,
      name: item.name,
      type: filterType,
      isMulti: false,
      options,
    };
  });
});

const hasActiveFilters = computed(() =>
  Object.values(appliedFilters.value).some(isFilterActive)
);

const isAllFilterSelected = computed(() => !filterListMenuItems.value.length);

const updateURLParams = () => {
  const params = generateCompleteURLParams({
    from: route.query.from,
    to: route.query.to,
    range: route.query.range,
    filters: {
      agent_id: appliedFilters.value.assigned_agent_id,
      inbox_id: appliedFilters.value.inbox_id,
      team_id: appliedFilters.value.team_id,
      sla_policy_id: appliedFilters.value.sla_policy_id,
      label: appliedFilters.value.label_list,
    },
  });
  router.replace({ query: params });
};

const emitChange = () => {
  updateURLParams();
  emit('filterChange', appliedFilters.value);
};

const showDropdown = () => {
  showSubDropdownMenu.value = false;
  showDropdownMenu.value = !showDropdownMenu.value;
};

const closeDropdown = () => {
  showDropdownMenu.value = false;
};

const openActiveFilterDropdown = filterType => {
  closeDropdown();
  activeFilterType.value = filterType;
  showSubDropdownMenu.value = !showSubDropdownMenu.value;
};

const closeActiveFilterDropdown = () => {
  activeFilterType.value = '';
  showSubDropdownMenu.value = false;
};

const resetDropdown = () => {
  closeDropdown();
  closeActiveFilterDropdown();
};

const addFilter = item => {
  const { type, id } = item;
  const filterKey = getFilterType(type, 'typeToKey');
  appliedFilters.value[filterKey] = MULTI_KEYS.includes(filterKey) ? [id] : id;
  emitChange();
  resetDropdown();
};

const updateMultiFilter = (type, ids) => {
  const filterKey = getFilterType(type, 'typeToKey');
  appliedFilters.value[filterKey] = ids;
  emitChange();
};

const removeFilter = type => {
  const filterKey = getFilterType(type, 'typeToKey');
  appliedFilters.value[filterKey] = MULTI_KEYS.includes(filterKey) ? [] : null;
  emitChange();
};

const clearAllFilters = () => {
  appliedFilters.value = {
    assigned_agent_id: [],
    inbox_id: [],
    team_id: [],
    sla_policy_id: null,
    label_list: [],
  };
  emitChange();
  resetDropdown();
};

const initializeFromURL = () => {
  const urlFilters = parseFilterURLParams(route.query);
  appliedFilters.value.assigned_agent_id = urlFilters.agent_id;
  appliedFilters.value.inbox_id = urlFilters.inbox_id;
  appliedFilters.value.team_id = urlFilters.team_id;
  appliedFilters.value.sla_policy_id = urlFilters.sla_policy_id;
  appliedFilters.value.label_list = urlFilters.label;
};

onMounted(() => {
  initializeFromURL();
  if (hasActiveFilters.value) {
    emitChange();
  }
});
</script>

<template>
  <div
    class="flex flex-col flex-wrap items-start gap-2 md:items-center md:flex-nowrap md:flex-row"
  >
    <!-- Active filters section -->
    <div v-if="hasActiveFilters" class="flex flex-wrap gap-2 md:flex-nowrap">
      <template v-for="filter in activeFilters" :key="filter.type">
        <ComboBox
          v-if="filter.isMulti"
          :model-value="filter.selectedIds"
          :options="filter.options"
          class="!w-48 [&>div>button]:h-8"
          multiple
          :placeholder="
            $t(
              `SLA_REPORTS.DROPDOWN.INPUT_PLACEHOLDER.${filter.type.toUpperCase()}`
            )
          "
          @update:model-value="ids => updateMultiFilter(filter.type, ids)"
        />
        <ActiveFilterChip
          v-else
          :id="filter.id"
          :name="filter.name"
          :type="filter.type"
          :options="filter.options"
          :placeholder="
            $t(
              `SLA_REPORTS.DROPDOWN.INPUT_PLACEHOLDER.${filter.type.toUpperCase()}`
            )
          "
          :active-filter-type="activeFilterType"
          :show-menu="showSubDropdownMenu"
          enable-search
          @toggle-dropdown="openActiveFilterDropdown"
          @close-dropdown="closeActiveFilterDropdown"
          @add-filter="addFilter"
          @remove-filter="removeFilter"
        />
      </template>
    </div>
    <!-- Dividing line between Active filters and Add filter button -->
    <div
      v-if="hasActiveFilters && !isAllFilterSelected"
      class="w-full h-px border md:w-px md:h-5 border-n-weak"
    />
    <!-- Add filter and clear filter button -->
    <div class="flex items-center gap-2">
      <AddFilterChip
        v-if="!isAllFilterSelected"
        placeholder-i18n-key="SLA_REPORTS.DROPDOWN.INPUT_PLACEHOLDER"
        :name="$t('SLA_REPORTS.DROPDOWN.ADD_FIlTER')"
        :menu-option="filterListMenuItems"
        :show-menu="showDropdownMenu"
        :empty-state-message="$t('SLA_REPORTS.DROPDOWN.NO_FILTER')"
        @toggle-dropdown="showDropdown"
        @close-dropdown="closeDropdown"
        @add-filter="addFilter"
      />

      <!-- Dividing line between Add filter and Clear all filter button -->
      <div v-if="hasActiveFilters" class="w-px h-5 border border-n-weak" />
      <!-- Clear all filter button -->
      <FilterButton
        v-if="hasActiveFilters"
        :button-text="$t('SLA_REPORTS.DROPDOWN.CLEAR_ALL')"
        @click="clearAllFilters"
      />
    </div>
  </div>
</template>
