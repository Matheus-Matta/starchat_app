import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const ACTIVITY_TYPES = [
  'call',
  'meeting',
  'task',
  'deadline',
  'email',
  'lunch',
];

export function usePipedriveFilterContext(resourceType, fetchers) {
  const { t } = useI18n();
  const { fetchUsers, fetchPersons, fetchOrganizations } = fetchers;

  const mapToOptions = opts => opts.map(o => ({ id: o.value, name: o.label }));

  const createStatusOption = (translationKey, value) => ({
    label: t(`INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.${translationKey}`),
    value,
  });

  const createTypeOption = (translationKey, value) => ({
    label: t(`INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.${translationKey}`),
    value,
  });

  const dealsStatus = computed(() => [
    createStatusOption('ALL_NOT_DELETED', 'all_not_deleted'),
    createStatusOption('OPEN', 'open'),
    createStatusOption('WON', 'won'),
    createStatusOption('LOST', 'lost'),
    createStatusOption('DELETED', 'deleted'),
  ]);

  const leadsStatus = computed(() => [
    createStatusOption('ACTIVE', 'not_archived'),
    createStatusOption('ARCHIVED', 'archived'),
  ]);

  const activityStatus = computed(() => [
    createStatusOption('PENDING', '0'),
    createStatusOption('DONE', '1'),
  ]);

  const activityTypes = computed(() =>
    ACTIVITY_TYPES.map(type => createTypeOption(type.toUpperCase(), type))
  );

  const equalToOperator = computed(() => [
    {
      value: 'equal_to',
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.OPERATORS.EQUAL_TO'),
      hasInput: true,
    },
  ]);

  const dateOperators = computed(() => [
    {
      value: 'is_greater_than',
      label: t(
        'INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.OPERATORS.IS_GREATER_THAN'
      ),
      hasInput: true,
    },
    {
      value: 'is_less_than',
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.OPERATORS.IS_LESS_THAN'),
      hasInput: true,
    },
  ]);

  const getStatusOptions = () => {
    const statusMap = {
      deals: dealsStatus.value,
      leads: leadsStatus.value,
      activities: activityStatus.value,
    };
    return statusMap[resourceType.value] || [];
  };

  const createFilter = (key, labelKey, inputType, operators, extra = {}) => ({
    attributeKey: key,
    value: key,
    label: t(`INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.ATTRIBUTES.${labelKey}`),
    inputType,
    filterOperators: operators,
    ...extra,
  });

  const createDateFilter = (key, labelKey) =>
    createFilter(key, labelKey, 'date', dateOperators.value);

  const baseFilters = computed(() => [
    createFilter('status', 'STATUS', 'searchSelect', equalToOperator.value, {
      options: mapToOptions(getStatusOptions()),
    }),
    createFilter(
      'owner_id',
      'USER',
      'asyncSearchSelect',
      equalToOperator.value,
      {
        fetchOptions: fetchUsers,
      }
    ),
    createFilter(
      'person_id',
      'PERSON',
      'asyncSearchSelect',
      equalToOperator.value,
      {
        fetchOptions: fetchPersons,
      }
    ),
    createFilter(
      'org_id',
      'ORGANIZATION',
      'asyncSearchSelect',
      equalToOperator.value,
      {
        fetchOptions: fetchOrganizations,
      }
    ),
    createDateFilter('add_time', 'ADD_TIME'),
    createDateFilter('update_time', 'UPDATE_TIME'),
  ]);

  const activitySpecificFilters = computed(() => [
    createFilter('type', 'TYPE', 'searchSelect', equalToOperator.value, {
      options: mapToOptions(activityTypes.value),
    }),
    createDateFilter('due_date', 'DUE_DATE'),
  ]);

  const filterTypes = computed(() => {
    const filters = [...baseFilters.value];

    if (resourceType.value === 'activities') {
      filters.push(...activitySpecificFilters.value);
    }

    return filters;
  });

  return { filterTypes };
}
