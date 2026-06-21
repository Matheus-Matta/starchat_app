<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCompaniesStore } from 'dashboard/stores/companies';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['import']);
const { t } = useI18n();
const companiesStore = useCompaniesStore();

const isImportingCompany = computed(
  () => companiesStore.getUIFlags.isImporting
);

const dialogRef = ref(null);
const fileInput = ref(null);

const hasSelectedFile = ref(null);
const selectedFileName = ref('');

const csvUrl = '/downloads/import-companies-sample.csv';

const handleFileClick = () => fileInput.value?.click();

const processFileName = fileName => {
  const lastDotIndex = fileName.lastIndexOf('.');
  const extension = fileName.slice(lastDotIndex);
  const baseName = fileName.slice(0, lastDotIndex);

  return baseName.length > 20
    ? `${baseName.slice(0, 20)}...${extension}`
    : fileName;
};

const handleFileChange = () => {
  const file = fileInput.value?.files[0];
  hasSelectedFile.value = file;
  selectedFileName.value = file ? processFileName(file.name) : '';
};

const handleRemoveFile = () => {
  hasSelectedFile.value = null;
  if (fileInput.value) {
    fileInput.value.value = null;
  }
  selectedFileName.value = '';
};

const uploadFile = async () => {
  if (!hasSelectedFile.value) return;
  emit('import', hasSelectedFile.value);
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('COMPANIES.ACTIONS.IMPORT.TITLE')"
    :confirm-button-label="t('COMPANIES.ACTIONS.IMPORT.IMPORT')"
    :is-loading="isImportingCompany"
    :disable-confirm-button="isImportingCompany"
    @confirm="uploadFile"
  >
    <template #description>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ t('COMPANIES.ACTIONS.IMPORT.DESCRIPTION') }}
        <a
          :href="csvUrl"
          target="_blank"
          rel="noopener noreferrer"
          download="import-companies-sample.csv"
          class="text-n-blue-11"
        >
          {{ t('COMPANIES.ACTIONS.IMPORT.DOWNLOAD_LABEL') }}
        </a>
      </p>
    </template>

    <div class="flex flex-col gap-2">
      <div class="flex items-center gap-2">
        <label class="text-sm text-n-slate-12 whitespace-nowrap">
          {{ t('COMPANIES.ACTIONS.IMPORT.LABEL') }}
        </label>
        <div class="flex items-center justify-between w-full gap-2">
          <span v-if="hasSelectedFile" class="text-sm text-n-slate-12">
            {{ selectedFileName }}
          </span>
          <Button
            v-if="!hasSelectedFile"
            :label="t('COMPANIES.ACTIONS.IMPORT.CHOOSE_FILE')"
            icon="i-lucide-upload"
            color="slate"
            variant="ghost"
            size="sm"
            class="!w-fit"
            @click="handleFileClick"
          />
          <div v-else class="flex items-center gap-1">
            <Button
              :label="t('COMPANIES.ACTIONS.IMPORT.CHANGE')"
              color="slate"
              variant="ghost"
              size="sm"
              @click="handleFileClick"
            />
            <div class="w-px h-3 bg-n-strong" />
            <Button
              icon="i-lucide-trash"
              color="slate"
              variant="ghost"
              size="sm"
              @click="handleRemoveFile"
            />
          </div>
        </div>
      </div>
    </div>
    <input
      ref="fileInput"
      type="file"
      accept="text/csv,.csv,.xls,.xlsx,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      class="hidden"
      @change="handleFileChange"
    />
  </Dialog>
</template>
