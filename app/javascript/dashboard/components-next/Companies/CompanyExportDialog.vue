<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompaniesStore } from 'dashboard/stores/companies';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['download', 'email']);

const { t } = useI18n();
const companiesStore = useCompaniesStore();

const dialogRef = ref(null);
const exportFormat = ref('csv');

const isExporting = computed(() => companiesStore.getUIFlags.isExporting);

const handleDownload = () => {
  emit('download', { format: exportFormat.value });
  dialogRef.value?.close();
};

const handleEmail = () => {
  emit('email', { format: exportFormat.value });
  dialogRef.value?.close();
};

const closeDialog = () => dialogRef.value?.close();

const open = () => {
  exportFormat.value = 'csv';
  dialogRef.value?.open();
};

defineExpose({ dialogRef, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('COMPANIES.ACTIONS.EXPORT.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="flex gap-3">
      <label
        class="flex flex-1 items-start gap-3 p-3 rounded-lg cursor-pointer border transition-colors"
        :class="
          exportFormat === 'csv'
            ? 'border-woot-500 bg-woot-25 dark:bg-woot-800/20'
            : 'border-n-weak hover:border-n-strong'
        "
      >
        <input
          v-model="exportFormat"
          type="radio"
          value="csv"
          class="mt-0.5 accent-woot-500"
        />
        <div class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('COMPANIES.ACTIONS.EXPORT.FORMAT_CSV_LABEL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.ACTIONS.EXPORT.FORMAT_CSV_DESC') }}
          </span>
        </div>
      </label>

      <label
        class="flex flex-1 items-start gap-3 p-3 rounded-lg cursor-pointer border transition-colors"
        :class="
          exportFormat === 'xlsx'
            ? 'border-woot-500 bg-woot-25 dark:bg-woot-800/20'
            : 'border-n-weak hover:border-n-strong'
        "
      >
        <input
          v-model="exportFormat"
          type="radio"
          value="xlsx"
          class="mt-0.5 accent-woot-500"
        />
        <div class="flex flex-col gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('COMPANIES.ACTIONS.EXPORT.FORMAT_XLSX_LABEL') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('COMPANIES.ACTIONS.EXPORT.FORMAT_XLSX_DESC') }}
          </span>
        </div>
      </label>
    </div>

    <template #footer>
      <div class="flex items-center w-full gap-2">
        <Button
          variant="faded"
          color="slate"
          :label="t('DIALOG.BUTTONS.CANCEL')"
          class="flex-1"
          type="button"
          :disabled="isExporting"
          @click="closeDialog"
        />
        <Button
          variant="faded"
          color="slate"
          :label="t('COMPANIES.ACTIONS.EXPORT.SEND_EMAIL')"
          class="flex-1"
          type="button"
          :disabled="isExporting"
          @click="handleEmail"
        />
        <Button
          color="blue"
          :label="t('COMPANIES.ACTIONS.EXPORT.DOWNLOAD')"
          class="flex-1"
          type="button"
          :is-loading="isExporting"
          :disabled="isExporting"
          @click="handleDownload"
        />
      </div>
    </template>
  </Dialog>
</template>
