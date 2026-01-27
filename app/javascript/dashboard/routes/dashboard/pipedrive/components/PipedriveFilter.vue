<script setup>
import { ref, watch, toRefs } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import ConditionRow from 'dashboard/components-next/filter/ConditionRow.vue';
import PipedriveAPI from 'dashboard/api/pipedrive';
import { usePipedriveFilterContext } from './pipedriveFilterProvider';

const props = defineProps({
  resourceType: { type: String, default: 'deals' }, // deals, leads, activities
  modelValue: { type: Array, default: () => [] },
});
const emit = defineEmits([
  'update:modelValue',
  'update:appliedFilters',
  'close',
]);

// Cache for async search results (separated by type)
const usersCache = ref([]); // For initial dropdown options
const personsCache = ref([]);
const organizationsCache = ref([]);

// "Known" items registry to allow looking up labels for searched items that aren't in the initial cache
const knownUsers = ref(new Map());
const knownPersons = ref(new Map());
const knownOrganizations = ref(new Map());

// Helper to accumulate known items
const addToKnown = (mapRef, items) => {
  if (!items || !items.length) return;
  items.forEach(item => {
    if (item && item.id) {
      mapRef.value.set(String(item.id), item);
    }
  });
};

// Async fetch functions
const fetchUsers = useDebounceFn(async (query, setOptions, setLoading) => {
  // Initial Load from Cache
  if (!query && usersCache.value.length > 0) {
    setOptions(usersCache.value);
    return;
  }

  if (setLoading) setLoading(true);
  try {
    const response = await PipedriveAPI.getUsers(query);
    const users = response.data.payload || [];

    addToKnown(knownUsers, users);
    if (!query) usersCache.value = users;

    setOptions(users);
  } catch (error) {
    setOptions([]);
  } finally {
    if (setLoading) setLoading(false);
  }
}, 500);

const fetchPersons = useDebounceFn(async (query, setOptions, setLoading) => {
  if (!query && personsCache.value.length > 0) {
    setOptions(personsCache.value);
    return;
  }

  if (setLoading) setLoading(true);
  try {
    const response = await PipedriveAPI.getPersons(query);
    const persons = response.data.payload || [];

    addToKnown(knownPersons, persons);
    if (!query) personsCache.value = persons;

    setOptions(persons);
  } catch (error) {
    setOptions([]);
  } finally {
    if (setLoading) setLoading(false);
  }
}, 500);

const fetchOrganizations = useDebounceFn(
  async (query, setOptions, setLoading) => {
    if (!query && organizationsCache.value.length > 0) {
      setOptions(organizationsCache.value);
      return;
    }

    if (setLoading) setLoading(true);
    try {
      const response = await PipedriveAPI.getOrganizations(query);
      const orgs = response.data.payload || [];

      addToKnown(knownOrganizations, orgs);
      if (!query) organizationsCache.value = orgs;

      setOptions(orgs);
    } catch (error) {
      setOptions([]);
    } finally {
      if (setLoading) setLoading(false);
    }
  },
  500
);

const { resourceType } = toRefs(props);
const { filterTypes } = usePipedriveFilterContext(resourceType, {
  fetchUsers,
  fetchPersons,
  fetchOrganizations,
});

const DEFAULT_FILTER = {
  attributeKey: 'status',
  filterOperator: 'equal_to',
  values: null,
  queryOperator: 'and',
};

// Local Filter State (decoupled from parent until apply)
const filters = ref([]);

// Sync from prop to local on mount/change
watch(
  () => props.modelValue,
  val => {
    if (val && val.length) {
      // Deep copy to detach referencing objects and avoid real-time preview update
      const parsed = JSON.parse(JSON.stringify(val));

      // Reverse map backend keys to generic UI keys for Date filters
      parsed.forEach(f => {
        if (f.attributeKey === 'created_from') {
          f.attributeKey = 'add_time';
          f.filterOperator = 'is_greater_than';
        } else if (f.attributeKey === 'created_to') {
          f.attributeKey = 'add_time';
          f.filterOperator = 'is_less_than';
        } else if (f.attributeKey === 'updated_from') {
          f.attributeKey = 'update_time';
          f.filterOperator = 'is_greater_than';
        } else if (f.attributeKey === 'updated_to') {
          f.attributeKey = 'update_time';
          f.filterOperator = 'is_less_than';
        }
      });

      filters.value = parsed;
    } else {
      // Always reset to default if external prop is empty
      filters.value = [{ ...DEFAULT_FILTER }];
    }
  },
  { immediate: true, deep: true }
);

// Watch filters to repopulate known items for async selects if editing existing filter
watch(
  filters,
  newFilters => {
    newFilters.forEach(filter => {
      if (filter.meta) {
        if (['owner_id', 'user_id'].includes(filter.attributeKey))
          knownUsers.value.set(String(filter.value), filter.meta);
        if (filter.attributeKey === 'person_id')
          knownPersons.value.set(String(filter.value), filter.meta);
        if (filter.attributeKey === 'org_id')
          knownOrganizations.value.set(String(filter.value), filter.meta);
      }
    });
  },
  { immediate: true, deep: true }
);

// Methods
const open = () => {
  // Just a placeholder for compatibility
};

const close = () => {
  emit('close');
};

const resetFilter = () => {
  filters.value = [{ ...DEFAULT_FILTER }];
};

const appendNewCondition = () => {
  filters.value.push({ ...DEFAULT_FILTER, queryOperator: 'and' });
};

const removeCondition = index => {
  if (filters.value.length === 1) {
    resetFilter();
  } else {
    filters.value.splice(index, 1);
  }
};

const applyFilter = () => {
  // Construct "Rich Payload"
  const richPayload = filters.value
    .map(filter => {
      // Constraint Check
      if (
        filter.values === null ||
        filter.values === undefined ||
        filter.values === ''
      ) {
        return null;
      }

      let value = filter.values;
      let label = '';
      let rawObject = null;

      // Determine Label and Value based on type
      if (typeof value === 'object' && value !== null) {
        // It's a select/search object
        rawObject = value;
        value = value.id !== undefined ? value.id : value.value; // Prefer ID, fallback to value
        label = rawObject.name || rawObject.label || rawObject.title || '';
      } else {
        // Primitive value (ID or String)
        label = String(value);

        // Label resolution for known types
        if (filter.attributeKey === 'status') {
          const typeDef = filterTypes.value.find(
            item => item.attributeKey === 'status'
          );
          const option = typeDef?.options?.find(o => o.id === value);
          if (option) label = option.name;
        } else if (['owner_id', 'user_id'].includes(filter.attributeKey)) {
          const found = knownUsers.value.get(String(value));
          if (found) {
            label = found.name;
            rawObject = found;
          }
        } else if (filter.attributeKey === 'person_id') {
          const found = knownPersons.value.get(String(value));
          if (found) {
            label = found.name;
            rawObject = found;
          }
        } else if (filter.attributeKey === 'org_id') {
          const found = knownOrganizations.value.get(String(value));
          if (found) {
            label = found.name;
            rawObject = found;
          }
        }
      }

      // Logic to convert generic date keys to specific backend keys
      let key = filter.attributeKey;
      if (key === 'add_time') {
        if (filter.filterOperator === 'is_greater_than') key = 'created_from';
        else if (filter.filterOperator === 'is_less_than') key = 'created_to';
      } else if (key === 'update_time') {
        if (filter.filterOperator === 'is_greater_than') key = 'updated_from';
        else if (filter.filterOperator === 'is_less_than') key = 'updated_to';
      }

      return {
        attributeKey: key,
        filterOperator: filter.filterOperator,
        queryOperator: filter.queryOperator,
        value: value, // The ID or raw string (Param Value for Backend)
        label: label, // The display name (UI Label)
        values: rawObject || label || value, // The value for ActiveFilterPreview (expects 'values')
        meta: rawObject, // The full object (UI State restoration)
        attributeLabel:
          filterTypes.value.find(
            item => item.attributeKey === filter.attributeKey
          )?.label || filter.attributeKey,
      };
    })
    .filter(f => f !== null);

  emit('update:modelValue', richPayload);
  emit('update:appliedFilters', richPayload);
  emit('close');
};

defineExpose({ open, close, reset: resetFilter });

const outsideClickHandler = [
  () => emit('close'),
  { ignore: ['#pipedrive-filter-button'] },
];
</script>

<template>
  <div
    v-on-click-outside="outsideClickHandler"
    class="z-40 max-w-3xl min-w-96 lg:w-[750px] overflow-visible w-full border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg rounded-xl p-6 grid gap-6"
  >
    <h3 class="text-base font-medium leading-6 text-n-slate-12">
      {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TITLE') }}
    </h3>
    <ul class="grid gap-4 list-none">
      <template v-for="(filter, index) in filters" :key="filter.id">
        <ConditionRow
          v-if="index === 0"
          :key="`filter-${filter.attributeKey}-0`"
          v-model:attribute-key="filter.attributeKey"
          v-model:filter-operator="filter.filterOperator"
          v-model:values="filter.values"
          :filter-types="filterTypes"
          :show-query-operator="false"
          @remove="removeCondition(index)"
        />
        <ConditionRow
          v-else
          :key="`filter-${filter.attributeKey}-${index}`"
          v-model:attribute-key="filter.attributeKey"
          v-model:filter-operator="filter.filterOperator"
          v-model:query-operator="filters[index - 1].queryOperator"
          v-model:values="filter.values"
          show-query-operator
          :filter-types="filterTypes"
          @remove="removeCondition(index)"
        />
      </template>
    </ul>
    <div class="flex justify-between gap-2">
      <Button sm ghost blue class="flex-shrink-0" @click="appendNewCondition">
        {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ADD_CONDITION') }}
      </Button>
      <div class="flex gap-2 flex-shrink-0">
        <Button sm faded slate @click="resetFilter">
          {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.CLEAR') }}
        </Button>
        <Button sm solid blue @click="applyFilter">
          {{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.APPLY') }}
        </Button>
      </div>
    </div>
  </div>
</template>
