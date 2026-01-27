<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PipedriveDealForm from '../forms/PipedriveDealForm.vue';

const emit = defineEmits(['create']);

const { t } = useI18n();
const store = useStore();
const show = ref(false);
const isCreating = ref(false);

const open = () => { show.value = true; };
const close = () => { show.value = false; };

const onSubmit = async (formData) => {
  isCreating.value = true;
  try {
    const payload = {
      deal: {
        title: formData.title,
        value: formData.value || null,
        currency: formData.currency,
        status: formData.status,
        person_id: formData.person_id || undefined,
        org_id: formData.org_id || undefined,
      },
      products: formData.product_id && formData.product_price ? [{
        product_id: parseInt(formData.product_id, 10),
        item_price: parseFloat(formData.product_price),
        quantity: parseInt(formData.product_quantity, 10) || 1,
      }] : undefined,
      discount: formData.discount_description && formData.discount_amount ? {
        description: formData.discount_description,
        amount: parseFloat(formData.discount_amount),
        type: formData.discount_type,
      } : undefined,
      installment: formData.installment_description && formData.installment_amount && formData.installment_date ? {
        description: formData.installment_description,
        amount: parseFloat(formData.installment_amount),
        billing_date: formData.installment_date,
      } : undefined
    };

    await store.dispatch('pipedrive/createDeal', payload);
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
  <Modal :show="show" @close="close" size="pipedrive-create-deal-modal">
    <div class="flex flex-col gap-6 w-full">
      <div class="flex items-center justify-between px-8 pt-8">
        <h2 class="text-xl font-medium text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_DEAL') }}
        </h2>
      </div>

      <div class="px-8 pb-8">
        <PipedriveDealForm
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
              :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_DEAL')"
              :is-loading="isCreating"
              :disabled="isCreating"
              type="submit"
            />
          </template>
        </PipedriveDealForm>
      </div>
    </div>
  </Modal>
</template>

<style lang="scss">
.pipedrive-create-deal-modal {
  @apply w-[1100px] max-w-[95vw] bg-n-slate-1;
}
</style>
