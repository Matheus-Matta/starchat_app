<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  type: { type: String, required: true }, // Lead, Deal, Activity
  onDelete: { type: Function, required: true },
  isDeleting: { type: Boolean, default: false },
});

const { t } = useI18n();
const [showDeleteSection, toggleDeleteSection] = useToggle();
const showConfirmModal = ref(false);

const typeLabel = computed(() => {
  const key = props.type === 'Activity' ? 'activity' : props.type.toLowerCase();
  return t(`INTEGRATION_SETTINGS.PIPEDRIVE.TYPES_SINGULAR.${key.toUpperCase()}`);
});

const openConfirmModal = () => {
  showConfirmModal.value = true;
};
const closeConfirmModal = () => {
  showConfirmModal.value = false;
};

const confirmDelete = async () => {
  await props.onDelete();
  closeConfirmModal();
};
</script>

<template>
  <div class="flex flex-col items-start border-t border-n-strong px-6 py-5">
    <Button
      :label="
        t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.LABEL', {
          type: typeLabel,
        })
      "
      size="sm"
      variant="link"
      color="slate"
      class="hover:!no-underline text-n-slate-12"
      icon="i-lucide-chevron-down"
      trailing-icon
      @click="toggleDeleteSection()"
    />

    <div
      class="transition-all duration-300 ease-in-out grid w-full overflow-hidden"
      :class="
        showDeleteSection
          ? 'grid-rows-[1fr] opacity-100 mt-2'
          : 'grid-rows-[0fr] opacity-0 mt-0'
      "
    >
      <div class="overflow-hidden min-h-0">
        <span class="inline-flex text-n-slate-11 text-sm items-center gap-1">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.MESSAGE') }}
          <Button
            :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.BUTTON')"
            size="sm"
            color="ruby"
            variant="link"
            @click="openConfirmModal"
          />
        </span>
      </div>
    </div>

    <!-- Simple Confirm Modal -->
    <Modal :show="showConfirmModal" @close="closeConfirmModal">
      <div class="p-8 flex flex-col gap-4">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.CONFIRM_TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.CONFIRM_MESSAGE', { type: typeLabel.toLowerCase() }) }}
        </p>
        <div class="flex justify-end gap-2 mt-4">
          <Button
            :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.CANCEL')"
            variant="ghost"
            color="slate"
            @click="closeConfirmModal"
          />
          <Button
            :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.BUTTON')"
            color="ruby"
            :is-loading="isDeleting"
            @click="confirmDelete"
          />
        </div>
      </div>
    </Modal>
  </div>
</template>
