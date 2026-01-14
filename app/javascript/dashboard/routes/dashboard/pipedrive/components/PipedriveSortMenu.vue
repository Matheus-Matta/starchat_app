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
    type: String, // 'asc' or 'desc'
    default: 'desc',
  },
});

const emit = defineEmits(['update:sort']);

const { t } = useI18n();

const isMenuOpen = ref(false);

const dealOptions = [
  { label: 'Data de Criação', value: 'add_time' },
  { label: 'Data de Atualização', value: 'update_time' },
  { label: 'Título', value: 'title' },
  { label: 'Valor', value: 'value' },
];

const leadOptions = [
  { label: 'Data de Criação', value: 'add_time' },
  { label: 'Data de Atualização', value: 'update_time' },
  { label: 'Título', value: 'title' },
];

const activityOptions = [
  { label: 'Data de Vencimento', value: 'due_date' },
  { label: 'Data de Criação', value: 'add_time' },
  { label: 'Data de Atualização', value: 'update_time' },
];

const sortMenus = computed(() => {
  if (props.resourceType === 'leads') return leadOptions;
  if (props.resourceType === 'activities') return activityOptions;
  return dealOptions;
});

const orderingMenus = [
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.OPTIONS.ASCENDING'),
    value: 'asc',
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.OPTIONS.DESCENDING'),
    value: 'desc',
  },
];

// Converted the props to refs for better reactivity
const activeSort = toRef(props, 'activeSort');
const activeOrdering = toRef(props, 'activeOrdering');

const activeSortLabel = computed(() => {
  const selectedMenu = sortMenus.value.find(
    menu => menu.value === activeSort.value
  );
  return (
    selectedMenu?.label || t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.LABEL')
  );
});

const activeOrderingLabel = computed(() => {
  const selectedMenu = orderingMenus.find(
    menu => menu.value === activeOrdering.value
  );
  return selectedMenu?.label || t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.LABEL');
});

const handleSortChange = value => {
  emit('update:sort', { sort_by: value, sort_direction: props.activeOrdering });
  isMenuOpen.value = false;
};

const handleOrderChange = value => {
  emit('update:sort', { sort_by: props.activeSort, sort_direction: value });
  isMenuOpen.value = false;
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
      class="absolute top-full mt-1 ltr:right-0 rtl:left-0 flex flex-col gap-4 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-72 rounded-xl p-4 z-50 shadow-lg"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.SORT_BY.LABEL') }}
        </span>
        <SelectMenu
          :model-value="activeSort"
          :options="sortMenus"
          :label="activeSortLabel"
          @update:model-value="handleSortChange"
        />
      </div>
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.ORDER.LABEL') }}
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
