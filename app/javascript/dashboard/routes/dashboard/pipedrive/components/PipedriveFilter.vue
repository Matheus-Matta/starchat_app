<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import ConditionRow from 'dashboard/components-next/filter/ConditionRow.vue';
import PipedriveAPI from 'dashboard/api/pipedrive';

const props = defineProps({
  resourceType: { type: String, default: 'deals' }, // deals, leads, activities
  activeStatus: { type: String, default: '' },
});
const emit = defineEmits(['update:filter', 'update:appliedFilters']);
const { t } = useI18n();
const isOpen = ref(false);

// Predefined Values Helper
const mapToOptions = opts => opts.map(o => ({ id: o.value, name: o.label }));

const dealsStatus = computed(() => [
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.ALL_NOT_DELETED'),
    value: 'all_not_deleted',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.OPEN'),
    value: 'open',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.WON'),
    value: 'won',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.LOST'),
    value: 'lost',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.DELETED'),
    value: 'deleted',
  },
]);

const leadsStatus = computed(() => [
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.ACTIVE'),
    value: 'not_archived',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.ARCHIVED'),
    value: 'archived',
  },
]);

const activityStatus = computed(() => [
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.PENDING'),
    value: '0',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.DONE'),
    value: '1',
  },
]);

const activityTypes = computed(() => [
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.CALL'),
    value: 'call',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.MEETING'),
    value: 'meeting',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.TASK'),
    value: 'task',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.DEADLINE'),
    value: 'deadline',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.EMAIL'),
    value: 'email',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.LUNCH'),
    value: 'lunch',
  },
]);

// Operators
const equalToOperator = computed(() => [
  {
    value: 'equal_to',
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.OPERATORS.EQUAL_TO'),
    hasInput: true,
  },
]);

const textOperators = computed(() => [
  {
    value: 'equal_to',
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.OPERATORS.EQUAL_TO'),
    hasInput: true,
  },
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

// Define Filter Types
const filterTypes = computed(() => {
  const types = [];

  // 1. Status Filter
  let statusOptions = [];
  if (props.resourceType === 'deals') statusOptions = dealsStatus.value;
  else if (props.resourceType === 'leads') statusOptions = leadsStatus.value;
  else if (props.resourceType === 'activities')
    statusOptions = activityStatus.value;

  types.push({
    attributeKey: 'status',
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.STATUS'),
    inputType: 'searchSelect',
    operators: equalToOperator.value,
    options: mapToOptions(statusOptions),
  });

  // 2. Owner Filter (owner_id)
  // Maps to owner_id param in backend. 'User' in Pipedrive context often means 'Owner'.
  types.push({
    attributeKey: 'owner_id',
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.USER'),
    inputType: 'asyncSearchSelect',
    operators: equalToOperator.value,
    fetchOptions: fetchUsers,
  });

  // 3. Person Filter
  types.push({
    attributeKey: 'person_id',
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.PERSON'),
    inputType: 'asyncSearchSelect',
    operators: equalToOperator.value,
    fetchOptions: fetchPersons,
  });

  // 4. Organization Filter
  types.push({
    attributeKey: 'org_id',
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.ORGANIZATION'),
    inputType: 'asyncSearchSelect',
    operators: equalToOperator.value,
    fetchOptions: fetchOrganizations,
  });

  // 5. Activity Specific
  if (props.resourceType === 'activities') {
    types.push({
      attributeKey: 'type',
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.TYPE'),
      inputType: 'searchSelect',
      operators: equalToOperator.value,
      options: mapToOptions(activityTypes.value),
    });
    types.push({
      attributeKey: 'due_date',
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.DUE_DATE'),
      inputType: 'date',
      operators: equalToOperator.value, // Simplified date (equal to)
    });
  }

  // 6. Stage (Deals Only)
  /*
  if (props.resourceType === 'deals') {
     // Requies fetching stages pipeline. Omitted for brevity unless requested.
  }
  */

  return types;
});

// Current Filter State
const filters = ref([
  {
    attributeKey: 'status',
    filterOperator: 'equal_to',
    values: '',
    queryOperator: 'and',
  },
]);

// Methods
const open = () => {
  isOpen.value = true;
};

const close = () => {
  isOpen.value = false;
};

const resetFilter = () => {
  filters.value = [
    {
      attributeKey: 'status',
      filterOperator: 'equal_to',
      values: '', // Reset to empty
      queryOperator: 'and',
    },
  ];
};

const appendNewCondition = () => {
  filters.value.push({
    attributeKey: 'owner_id', // Default to next useful filter
    filterOperator: 'equal_to',
    values: '',
    queryOperator: 'and',
  });
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
  const richPayload = filters.value.map(filter => {
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
         const typeDef = filterTypes.value.find(item => item.attributeKey === 'status');
         const option = typeDef?.options?.find(o => o.id === value);
         if (option) label = option.name;
      }
      else if (['owner_id', 'user_id'].includes(filter.attributeKey)) {
         const found = knownUsers.value.get(String(value));
         if (found) {
            label = found.name;
            rawObject = found;
         }
      }
      else if (filter.attributeKey === 'person_id') {
         const found = knownPersons.value.get(String(value));
         if (found) {
            label = found.name;
            rawObject = found;
         }
      }
      else if (filter.attributeKey === 'org_id') {
         const found = knownOrganizations.value.get(String(value));
         if (found) {
            label = found.name;
            rawObject = found;
         }
      }
    }

    return {
      attributeKey: filter.attributeKey,
      filterOperator: filter.filterOperator,
      queryOperator: filter.queryOperator,
      value: value,       // The ID or raw string (Param Value for Backend)
      label: label,       // The display name (UI Label)
      values: rawObject || label || value, // The value for ActiveFilterPreview (expects 'values')
      meta: rawObject,    // The full object (UI State restoration)
      attributeLabel: filterTypes.value.find(item => item.attributeKey === filter.attributeKey)?.label || filter.attributeKey
    };
  });

  emit('update:appliedFilters', richPayload);
  isOpen.value = false;
};

// Reconstruct UI state from saved payload
const setFilters = (savedFilters) => {
  if (!savedFilters || !savedFilters.length) {
    resetFilter();
    return;
  }

  filters.value = savedFilters.map(savedItem => {
    // If we have meta (full object), use it. Otherwise construct minimal object from label/value.
    let reconstructedValue = savedItem.value;

    if (['owner_id', 'user_id', 'person_id', 'org_id', 'status'].includes(savedItem.attributeKey)) {
        if (savedItem.meta) {
           reconstructedValue = savedItem.meta;
        } else if (savedItem.label) {
           reconstructedValue = {
             id: savedItem.value,
             name: savedItem.label,
             label: savedItem.label,
           };
        }
    }

    // Populate Kown Items Cache from saved data to ensure future edits work
    if (savedItem.meta) {
       if (['owner_id', 'user_id'].includes(savedItem.attributeKey)) knownUsers.value.set(String(savedItem.value), savedItem.meta);
       if (savedItem.attributeKey === 'person_id') knownPersons.value.set(String(savedItem.value), savedItem.meta);
       if (savedItem.attributeKey === 'org_id') knownOrganizations.value.set(String(savedItem.value), savedItem.meta);
    }

    return {
      attributeKey: savedItem.attributeKey,
      filterOperator: savedItem.filterOperator || 'equal_to',
      queryOperator: savedItem.queryOperator || 'and',
      values: reconstructedValue, 
    };
  });
};

defineExpose({ open, close, setFilters, reset: resetFilter });
</script>

<template>
  <div class="flex flex-col">
    <!-- Modal logic handled by parent commonly, but here we can emit event or just use isOpen if wrapper handles it -->
    <div v-if="isOpen" class="fixed inset-0 z-40 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div class="w-full max-w-3xl bg-white rounded-xl shadow-xl border border-n-weak p-6 flex flex-col gap-4 animate-fade-in relative">
         
         <div class="flex justify-between items-center mb-2">
            <h3 class="text-lg font-medium text-n-slate-12">
               {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TITLE') }}
            </h3>
            <button @click="close" class="text-n-slate-11 hover:text-n-slate-12">
               <span class="i-lucide-x w-5 h-5" />
            </button>
         </div>

         <div class="flex flex-col gap-3 min-h-[200px] max-h-[60vh] overflow-y-auto">
            <ConditionRow
               v-for="(filter, index) in filters"
               :key="index"
               v-model:attribute-key="filter.attributeKey"
               v-model:filter-operator="filter.filterOperator"
               v-model:values="filter.values"
               :attributes="filterTypes"
               :show-query-operator="index > 0"
               :query-operator="filter.queryOperator"
               @remove="removeCondition(index)"
               @update:queryOperator="(val) => filter.queryOperator = val"
            />
         </div>

         <div class="flex items-center gap-2 mt-2">
            <Button
               variant="ghost"
               color="slate"
               size="sm"
               @click="appendNewCondition"
            >
               <span class="i-lucide-plus w-4 h-4 mr-1" />
               {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ADD_CONDITION') }}
            </Button>
         </div>

         <div class="flex justify-between items-center mt-6 pt-4 border-t border-n-weak">
            <Button
               variant="ghost"
               color="slate"
               @click="resetFilter" 
            >
               {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.CLEAR') }}
            </Button>
            <div class="flex gap-2">
               <Button variant="ghost" color="slate" @click="close">
                  {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.CANCEL') }}
               </Button>
               <Button color="blue" @click="applyFilter">
                  {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.APPLY') }}
               </Button>
            </div>
         </div>

      </div>
    </div>
  </div>
</template>
