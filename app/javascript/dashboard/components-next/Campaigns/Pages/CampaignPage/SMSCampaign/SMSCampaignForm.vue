<script setup>
import { reactive, computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import AudienceBuilder from 'dashboard/components-next/Campaigns/AudienceBuilder/AudienceBuilder.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getSMSInboxes'),
};

const initialState = {
  title: '',
  message: '',
  inboxId: null,
  scheduledAt: null,
  selectedAudience: [],
};

const state = reactive({ ...initialState });

const contactsPreview = ref({ count: null, isLoading: false });
let previewDebounceTimer = null;

const rules = {
  title: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.SMS.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  message: getErrorMessage('message', 'MESSAGE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const isSubmitDisabled = computed(() => v$.value.$invalid);

const audiencePreviewText = computed(() => {
  if (contactsPreview.value.isLoading) return t('CAMPAIGN.AUDIENCE_PREVIEW.LOADING');
  if (contactsPreview.value.count === null) return null;
  if (contactsPreview.value.count === 0) return t('CAMPAIGN.AUDIENCE_PREVIEW.NONE');
  return t('CAMPAIGN.AUDIENCE_PREVIEW.COUNT', { count: contactsPreview.value.count });
});

const fetchContactsPreview = async audience => {
  if (!audience.length) {
    contactsPreview.value = { count: null, isLoading: false };
    return;
  }
  contactsPreview.value.isLoading = true;
  const data = await store.dispatch('campaigns/previewContacts', { audience });
  contactsPreview.value = { count: data.count ?? 0, isLoading: false };
};

watch(
  () => state.selectedAudience,
  newAudience => {
    clearTimeout(previewDebounceTimer);
    previewDebounceTimer = setTimeout(() => fetchContactsPreview(newAudience), 500);
  }
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  contactsPreview.value = { count: null, isLoading: false };
};

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => ({
  title: state.title,
  message: state.message,
  inbox_id: state.inboxId,
  scheduled_at: formatToUTCString(state.scheduledAt),
  audience: state.selectedAudience,
});

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.SMS.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <TextArea
      v-model="state.message"
      :label="t('CAMPAIGN.SMS.CREATE.FORM.MESSAGE.LABEL')"
      :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.MESSAGE.PLACEHOLDER')"
      show-character-count
      :message="formErrors.message"
      :message-type="formErrors.message ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.SMS.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <AudienceBuilder
      v-model="state.selectedAudience"
      :has-error="!!formErrors.audience"
      :message="formErrors.audience"
    />
    <p
      v-if="audiencePreviewText"
      class="text-xs -mt-1"
      :class="contactsPreview.count === 0 ? 'text-n-ruby-11' : 'text-n-teal-11'"
    >
      {{ audiencePreviewText }}
    </p>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.SMS.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="flex items-center justify-between w-full gap-3">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.SMS.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.SMS.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
