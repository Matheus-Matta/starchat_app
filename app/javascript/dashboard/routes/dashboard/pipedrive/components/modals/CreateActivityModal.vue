<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PipedriveActivityForm from '../forms/PipedriveActivityForm.vue';

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
    const payload = { ...formData };
    if (!payload.deal_id) delete payload.deal_id;
    if (!payload.lead_id) delete payload.lead_id;
    if (!payload.person_id) delete payload.person_id;
    if (!payload.org_id) delete payload.org_id;
    if (!payload.note) delete payload.note;
    if (!payload.public_description) delete payload.public_description;
    if (!payload.due_date) delete payload.due_date;
    if (!payload.due_time) delete payload.due_time;
    if (!payload.duration) delete payload.duration;
    if (!payload.priority) delete payload.priority;

    await store.dispatch('pipedrive/createActivity', payload);
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
  <Modal :show="show" @close="close" size="pipedrive-create-activity-modal">
    <div class="flex flex-col gap-6 w-full">
      <div class="flex items-center justify-between px-8 pt-8">
        <h2 class="text-xl font-medium text-n-slate-12">
          {{ t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_ACTIVITY') }}
        </h2>
      </div>

      <div class="px-8 pb-8">
        <PipedriveActivityForm
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
              :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.CREATE_ACTIVITY')"
              :is-loading="isCreating"
              :disabled="isCreating"
              type="submit"
            />
          </template>
        </PipedriveActivityForm>
      </div>
    </div>
  </Modal>
</template>

<style lang="scss">
.pipedrive-create-activity-modal {
  @apply w-[1100px] max-w-[95vw] bg-n-slate-1;
}
</style>
