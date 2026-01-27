<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import PipedriveItemCard from './PipedriveItemCard.vue';
import PipedriveActivityForm from './forms/PipedriveActivityForm.vue';
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
  console.log('[ActivityCard] Manual submit trigger for Activity:', props.item.id);
  formRef.value?.submit();
};

onMounted(() => {
  console.log('[ActivityCard] Initial Item Data:', props.item);
});

const onUpdate = async formData => {
  isUpdating.value = true;
  try {
    await PipedriveAPI.updateActivity(props.item.id, formData);
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
    await PipedriveAPI.deleteActivity(props.item.id);
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.API.SUCCESS_MESSAGE'));
    emit('refresh');
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PIPEDRIVE.DELETE.API.ERROR_MESSAGE'));
  } finally {
    isDeleting.value = false;
  }
};

const title = computed(
  () =>
    props.item.subject || t('INTEGRATION_SETTINGS.PIPEDRIVE.EMPTY_VALUE.TITLE')
);
const subtitle = computed(() => {
  const parts = [];
  if (props.item.type) {
    parts.push(t(`INTEGRATION_SETTINGS.PIPEDRIVE.FILTERS.TYPES.${props.item.type.toUpperCase()}`));
  }
  if (props.item.due_date) {
    parts.push(props.item.due_date); // Already formatted by backend in many cases
  }
  if (props.item.owner_name || props.item.user_id) {
    parts.push(`Responsável: ${props.item.owner_name || props.item.user_id}`);
  }
  if (props.item.lead_id) {
    parts.push(`Lead: ${props.item.lead_id.substring(0, 8)}...`);
  }
  return parts.join(' · ') || t('INTEGRATION_SETTINGS.PIPEDRIVE.EMPTY_VALUE.DATE');
});
</script>

<template>
  <PipedriveItemCard
    :is-expanded="isExpanded"
    :title="title"
    :subtitle="subtitle"
    :pipedrive-link="item.pipedrive_link"
    icon="i-lucide-calendar"
    @toggle="isExpanded = !isExpanded"
  >
    <template #content>
      <div v-if="isExpanded">
        <div class="flex flex-col gap-6 p-6">
          <PipedriveActivityForm
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
          type="Activity"
          :is-deleting="isDeleting"
          :on-delete="onDelete"
        />
        <!-- Debug raw data removed from UI, check console -->
      </div>
    </template>
  </PipedriveItemCard>
</template>
