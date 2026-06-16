<script setup>
import { useI18n } from 'vue-i18n';
import {
  DropdownContainer,
  DropdownBody,
  DropdownItem,
} from 'dashboard/components-next/dropdown-menu/base';

defineProps({
  label: { type: String, required: true },
});

const emit = defineEmits(['download']);
const { t } = useI18n();
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle, isOpen }">
      <button
        type="button"
        class="inline-flex items-center min-w-0 gap-2 h-8 px-3 text-sm transition-all duration-100 ease-out border-0 rounded-lg outline-1 outline bg-n-button-color hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 text-n-slate-12 outline-n-container active:scale-[0.97]"
        :class="{ 'bg-n-alpha-2': isOpen }"
        @click="toggle"
      >
        <span class="i-ph-download-simple size-4 flex-shrink-0" />
        <span class="min-w-0 truncate">{{ label }}</span>
        <span
          class="i-lucide-chevron-down size-3.5 flex-shrink-0 transition-transform duration-200"
          :class="{ 'rotate-180': isOpen }"
        />
      </button>
    </template>
    <DropdownBody class="top-0 mt-1 ltr:right-0 rtl:left-0 z-50 min-w-[140px]">
      <DropdownItem
        :label="t('REPORT.DOWNLOAD_FORMAT.CSV')"
        icon="i-ph-file-csv"
        :click="() => emit('download', 'csv')"
      />
      <DropdownItem
        :label="t('REPORT.DOWNLOAD_FORMAT.XLS')"
        icon="i-ph-file-xls"
        :click="() => emit('download', 'xls')"
      />
    </DropdownBody>
  </DropdownContainer>
</template>
