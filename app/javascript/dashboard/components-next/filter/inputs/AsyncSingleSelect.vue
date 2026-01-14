<script setup>
import { defineModel, computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import Button from 'next/button/Button.vue';
import DropdownContainer from 'next/dropdown-menu/base/DropdownContainer.vue';
import DropdownSection from 'next/dropdown-menu/base/DropdownSection.vue';
import DropdownBody from 'next/dropdown-menu/base/DropdownBody.vue';
import DropdownItem from 'next/dropdown-menu/base/DropdownItem.vue';

const {
  fetchOptions,
  placeholderIcon,
  placeholder,
  placeholderTrailingIcon,
  searchPlaceholder,
} = defineProps({
  fetchOptions: {
    type: Function,
    required: true,
  },
  placeholderIcon: {
    type: String,
    default: 'i-lucide-plus',
  },
  placeholder: {
    type: String,
    default: '',
  },
  placeholderTrailingIcon: {
    type: Boolean,
    default: false,
  },
  searchPlaceholder: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const selected = defineModel({
  type: Object,
  required: true,
});

const searchTerm = ref('');
const options = ref([]);
const isLoading = ref(false);

// Function to update options from async source
const setOptions = newOptions => {
  options.value = newOptions;
};

const setLoading = loading => {
  isLoading.value = loading;
};

// Watch searchTerm and trigger fetch
watch(
  searchTerm,
  newTerm => {
    console.log('[AsyncSingleSelect] Search term changed:', newTerm);
    fetchOptions(newTerm, setOptions, setLoading);
  },
  { immediate: true }
);

// Watch selected to reset searchTerm when cleared externally (e.g., filter type change)
watch(selected, newValue => {
  if (!newValue || Object.keys(newValue).length === 0) {
    searchTerm.value = '';
    options.value = []; // Clear options to avoid showing old data
  }
});

// Watch fetchOptions to reload when filter type changes (e.g., User -> Person)
watch(
  () => fetchOptions,
  () => {
    // Reset and trigger initial load for new type
    searchTerm.value = '';
    options.value = [];
    // Trigger fetch with empty query to load initial options
    fetchOptions('', setOptions, setLoading);
  }
);

const selectedItem = computed(() => {
  if (!options.value) return null;
  if (!selected.value) return null;

  const optionToSearch = Array.isArray(selected.value)
    ? selected.value[0]
    : selected.value;

  return options.value.find(option => option.id === optionToSearch.id);
});

const toggleSelected = option => {
  const optionToToggle = {
    id: option.id,
    name: option.name,
  };

  if (selected.value && selected.value.id === optionToToggle.id) {
    selected.value = null;
  } else {
    selected.value = optionToToggle;
  }
};
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle }">
      <Button
        v-if="selectedItem"
        sm
        slate
        faded
        type="button"
        :icon="selectedItem.icon"
        :label="selectedItem.name"
        @click="toggle"
      />
      <Button
        v-else
        sm
        slate
        faded
        type="button"
        :trailing-icon="placeholderTrailingIcon"
        @click="toggle"
      >
        <template #icon>
          <Icon :icon="placeholderIcon" class="text-n-slate-11" />
        </template>
        <span class="text-n-slate-11">{{
          placeholder || t('COMBOBOX.PLACEHOLDER')
        }}</span>
      </Button>
    </template>
    <DropdownBody class="top-0 min-w-56 z-50" strong>
      <div class="relative">
        <Icon
          v-if="!isLoading"
          class="absolute size-4 left-2 top-2"
          icon="i-lucide-search"
        />
        <Icon
          v-else
          class="absolute size-4 left-2 top-2 animate-spin"
          icon="i-lucide-loader-circle"
        />
        <input
          v-model="searchTerm"
          autofocus
          class="p-1.5 pl-8 text-n-slate-11 bg-n-alpha-1 rounded-lg w-full"
          :placeholder="searchPlaceholder || t('COMBOBOX.SEARCH_PLACEHOLDER')"
        />
      </div>
      <DropdownSection class="[&>ul]:max-h-80">
        <template v-if="options.length">
          <DropdownItem
            v-for="option in options"
            :key="option.id"
            :icon="option.icon"
            @click="toggleSelected(option)"
          >
            <template #label>
              {{ option.name }}
              <Icon
                v-if="selectedItem && selectedItem.id === option.id"
                icon="i-lucide-check"
                class="bg-n-blue-text pointer-events-none"
              />
            </template>
          </DropdownItem>
        </template>
        <template v-else-if="isLoading">
          <DropdownItem disabled>
            {{ t('COMBOBOX.LOADING') }}
          </DropdownItem>
        </template>
        <template v-else-if="searchTerm">
          <DropdownItem disabled>
            {{ t('COMBOBOX.EMPTY_SEARCH_RESULTS', { searchTerm: searchTerm }) }}
          </DropdownItem>
        </template>
        <template v-else>
          <DropdownItem disabled>
            {{ t('COMBOBOX.EMPTY_STATE') }}
          </DropdownItem>
        </template>
      </DropdownSection>
    </DropdownBody>
  </DropdownContainer>
</template>
