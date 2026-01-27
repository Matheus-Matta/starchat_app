<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import PipedriveItemCard from './PipedriveItemCard.vue';
import PipedriveDealForm from './forms/PipedriveDealForm.vue';
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
  console.log('[DealCard] Manual submit trigger for Deal:', props.item.id);
  formRef.value?.submit();
};

onMounted(() => {
  console.log('[DealCard] Initial Item Data:', props.item);
});

const onUpdate = async formData => {
  isUpdating.value = true;
  try {
    await PipedriveAPI.updateDeal(props.item.id, formData);
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
    await PipedriveAPI.deleteDeal(props.item.id);
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.API.SUCCESS_MESSAGE'));
    emit('refresh');
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.API.ERROR_MESSAGE'));
  } finally {
    isDeleting.value = false;
  }
};

const formatCurrency = (amount, currency) => {
  if (!amount || !currency) return t('INTEGRATION_SETTINGS.PIPEDRIVE.EMPTY_VALUE.VALUE');
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency }).format(amount);
};

const subtitle = computed(() =>
  [
    formatCurrency(props.item.value, props.item.currency),
    props.item.status
      ? t(
          `INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.STATUS.${props.item.status.toUpperCase()}`
        )
      : '---',
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
    icon="i-lucide-banknote"
    @toggle="isExpanded = !isExpanded"
  >
    <template #content>
      <div v-if="isExpanded">
        <div class="flex flex-col gap-6 p-6">
          <PipedriveDealForm
            ref="formRef"
            :initial-data="item"
            :is-loading="isUpdating"
            @submit="onUpdate"
          />
          <div>
            <Button
              :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.UPDATE_BUTTON')"
              size="sm"
              :is-loading="isUpdating"
              :disabled="isUpdating"
              @click="triggerSubmit"
            />
          </div>
        </div>
        <PipedriveItemDeleteSection
          type="Deal"
          :is-deleting="isDeleting"
          :on-delete="onDelete"
        />
      </div>
    </template>
  </PipedriveItemCard>
</template>
