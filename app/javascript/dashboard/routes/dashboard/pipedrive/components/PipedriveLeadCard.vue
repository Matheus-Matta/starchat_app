<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import PipedriveItemCard from './PipedriveItemCard.vue';
import PipedriveLeadForm from './forms/PipedriveLeadForm.vue';
import PipedriveItemDeleteSection from './PipedriveItemDeleteSection.vue';
import Button from 'dashboard/components-next/button/Button.vue';

import { useAlert } from 'dashboard/composables';
import PipedriveAPI from 'dashboard/api/integrations/pipedrive';

const props = defineProps({
  item: { type: Object, required: true },
});

const emit = defineEmits(['refresh']);

const { t } = useI18n();
const isExpanded = ref(false);
const isUpdating = ref(false);
const isDeleting = ref(false);
const formRef = ref(null);

const triggerSubmit = () => {
  console.log('[LeadCard] Manual submit trigger for Lead:', props.item.id);
  formRef.value?.submit();
};

onMounted(() => {
  console.log('[LeadCard] Initial Item Data:', props.item);
});

const onUpdate = async formData => {
  isUpdating.value = true;
  try {
    await PipedriveAPI.updateLead(props.item.id, formData);
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.UPDATE_SUCCESS'));
    emit('refresh');
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.UPDATE_ERROR'));
  } finally {
    isUpdating.value = false;
  }
};

const onDelete = async () => {
  isDeleting.value = true;
  try {
    await PipedriveAPI.deleteLead(props.item.id);
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.API.SUCCESS_MESSAGE'));
    emit('refresh');
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.API.ERROR_MESSAGE'));
  } finally {
    isDeleting.value = false;
  }
};

const subtitle = computed(() =>
  [
    props.item.value?.amount
      ? `${props.item.value.amount} ${props.item.value.currency}`
      : t('INTEGRATION_SETTINGS.PIPEDRIVE.EMPTY_VALUE.VALUE'),
    props.item.add_time
      ? new Date(props.item.add_time).toLocaleDateString('pt-BR')
      : t('INTEGRATION_SETTINGS.PIPEDRIVE.EMPTY_VALUE.DATE'),
  ].join(' · ')
);
</script>

<template>
  <PipedriveItemCard
    :is-expanded="isExpanded"
    :title="item.title"
    :subtitle="subtitle"
    :pipedrive-link="item.pipedrive_link"
    icon="i-lucide-users"
    @toggle="isExpanded = !isExpanded"
  >
    <template #content>
      <div v-if="isExpanded">
        <div class="p-6">
          <PipedriveLeadForm
            ref="formRef"
            :initial-data="item"
            :is-loading="isUpdating"
            @submit="onUpdate"
          >
            <template #actions>
              <Button
                :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.UPDATE_BUTTON')"
                size="sm"
                :is-loading="isUpdating"
                :disabled="isUpdating"
                @click="triggerSubmit"
              />
            </template>
          </PipedriveLeadForm>
        </div>
        <PipedriveItemDeleteSection
          type="Lead"
          :is-deleting="isDeleting"
          :on-delete="onDelete"
        />
        <div class="px-6 pb-6">
          <details class="text-xs text-n-slate-11">
            <summary class="cursor-pointer hover:text-n-slate-12">Ver dados brutos (Debug)</summary>
            <pre class="mt-2 p-2 bg-n-alpha-2 rounded overflow-auto max-h-40">{{ JSON.stringify(item, null, 2) }}</pre>
          </details>
        </div>
      </div>
    </template>
  </PipedriveItemCard>
</template>
