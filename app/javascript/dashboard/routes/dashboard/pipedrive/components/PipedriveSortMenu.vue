<script setup>
import { ref, computed, toRef } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

const props = defineProps({
  resourceType: {
    type: String,
    default: 'deals',
  },
  activeSort: {
    type: String,
    default: 'add_time',
  },
  activeOrdering: {
    type: String,
    default: 'desc',
  },
});

const emit = defineEmits(['update:sort']);

const { t } = useI18n();

const isMenuOpen = ref(false);

// Sort options per resource type
const sortOptions = computed(() => {
  const common = [
    {
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.ADD_TIME'),
      value: 'add_time',
    },
    {
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.UPDATE_TIME'),
      value: 'update_time',
    },
    {
      label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.TITLE'),
      value: 'title',
    },
  ];

  if (props.resourceType === 'deals') {
    return [
      ...common,
      {
        label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.VALUE'),
        value: 'value',
      },
      {
        label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.STAGE'),
        value: 'stage_id',
      },
    ];
  }

  if (props.resourceType === 'activities') {
    return [
      {
        label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.DUE_DATE'),
        value: 'due_date',
      },
      {
        label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.ADD_TIME'),
        value: 'add_time',
      },
      {
        label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.UPDATE_TIME'),
        value: 'update_time',
      },
      {
        label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.OPTIONS.SUBJECT'),
        value: 'subject',
      },
    ];
  }

  // leads
  return common;
});

const orderingMenus = [
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.ORDER.ASCENDING'),
    value: 'asc',
  },
  {
    label: t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.ORDER.DESCENDING'),
    value: 'desc',
  },
];

// Converted the props to refs for better reactivity
const activeSort = toRef(props, 'activeSort');
const activeOrdering = toRef(props, 'activeOrdering');

const activeSortLabel = computed(() => {
  const selectedMenu = sortOptions.value.find(
    menu => menu.value === activeSort.value
  );
  return (
    selectedMenu?.label || t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.SORT_BY')
  );
});

const activeOrderingLabel = computed(() => {
  const selectedMenu = orderingMenus.find(
    menu => menu.value === activeOrdering.value
  );
  return (
    selectedMenu?.label ||
    t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.ORDER.DESCENDING')
  );
});

const handleSortChange = value => {
  emit('update:sort', { sort_by: value, sort_direction: props.activeOrdering });
};

const handleOrderChange = value => {
  emit('update:sort', { sort_by: props.activeSort, sort_direction: value });
};
</script>

<template>
  <div class="relative">
    <Button
      icon="i-lucide-arrow-down-up"
      color="slate"
      size="sm"
      variant="ghost"
      :class="isMenuOpen ? 'bg-n-alpha-2' : ''"
      @click="isMenuOpen = !isMenuOpen"
    />
    <div
      v-if="isMenuOpen"
      v-on-clickaway="() => (isMenuOpen = false)"
      class="absolute top-full mt-1 ltr:right-0 rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4 shadow-lg z-50"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.SORT_BY') }}
        </span>
        <SelectMenu
          :model-value="activeSort"
          :options="sortOptions"
          :label="activeSortLabel"
          @update:model-value="handleSortChange"
        />
      </div>
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.SORT.ORDER.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeOrdering"
          :options="orderingMenus"
          :label="activeOrderingLabel"
          @update:model-value="handleOrderChange"
        />
      </div>
    </div>
  </div>
</template>
