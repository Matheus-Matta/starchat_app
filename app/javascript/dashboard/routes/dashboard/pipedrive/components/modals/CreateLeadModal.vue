<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PipedriveLeadForm from '../forms/PipedriveLeadForm.vue';

const emit = defineEmits(['create']);

const { t } = useI18n();
const store = useStore();
const show = ref(false);
const isCreating = ref(false);

const open = () => { show.value = true; };
const close = () => { show.value = false; };

const onSubmit = async (formData) => {
  if (!formData.person_id && !formData.organization_id) {
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.LEAD_REQ_PERSON_OR_ORG'));
    return;
  }

  isCreating.value = true;
  try {
    const payload = {
      title: formData.title,
      value: {
        amount: parseFloat(formData.amount) || 0,
        currency: formData.currency,
      },
      person_id: formData.person_id ? parseInt(formData.person_id, 10) : undefined,
      organization_id: formData.organization_id ? parseInt(formData.organization_id, 10) : undefined,
      owner_id: formData.owner_id ? parseInt(formData.owner_id, 10) : undefined,
      label_ids: formData.label_ids.length ? formData.label_ids : undefined,
      expected_close_date: formData.expected_close_date || undefined,
      visible_to: formData.visible_to,
      was_seen: formData.was_seen,
    };
    await store.dispatch('pipedrive/createLead', payload);
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_SUCCESS'));
    emit('create');
    close();
  } catch (error) {
    useAlert(error.message || t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Modal :show="show" @close="close" size="pipedrive-create-lead-modal">
    <div class="flex flex-col gap-6 w-full">
      <div class="flex items-center justify-between px-8 pt-8">
        <h2 class="text-xl font-medium text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_LEAD') }}
        </h2>
      </div>

      <div class="px-8 pb-8">
        <PipedriveLeadForm
          :is-loading="isCreating"
          actions-class="justify-end"
          @submit="onSubmit"
        >
          <template #actions>
            <Button
              :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.CANCEL')"
              variant="ghost"
              color="slate"
              @click="close"
            />
            <Button
              :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_LEAD')"
              :is-loading="isCreating"
              :disabled="isCreating"
              type="submit"
            />
          </template>
        </PipedriveLeadForm>
      </div>
    </div>
  </Modal>
</template>

<style lang="scss">
.pipedrive-create-lead-modal {
  @apply w-[1100px] max-w-[95vw] bg-n-slate-1;
}
</style>
