<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';
import AudienceBuilder from 'dashboard/components-next/Campaigns/AudienceBuilder/AudienceBuilder.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const store = useStore();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  message: '',
  scheduledAt: null,
  selectedAudience: [],
};

const state = reactive({ ...initialState });
const templateParserRef = ref(null);
const contactsPreview = ref({ count: null, isLoading: false });
let previewDebounceTimer = null;

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
  selectedAudience: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  // Added to disable the scheduled at field from being set to the current time
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

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    // Create a more user-friendly label from template name
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());

    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: getErrorMessage('selectedAudience', 'AUDIENCE'),
}));

const hasRequiredTemplateParams = computed(() => {
  if (!selectedTemplate.value) return state.message.trim().length > 0;
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value
);

const audiencePreviewText = computed(() => {
  if (contactsPreview.value.isLoading)
    return t('CAMPAIGN.AUDIENCE_PREVIEW.LOADING');
  if (contactsPreview.value.count === null) return null;
  if (contactsPreview.value.count === 0)
    return t('CAMPAIGN.AUDIENCE_PREVIEW.NONE');
  return t('CAMPAIGN.AUDIENCE_PREVIEW.COUNT', {
    count: contactsPreview.value.count,
  });
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

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  v$.value.$reset();
  contactsPreview.value = { count: null, isLoading: false };
};

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => {
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;

  const payload = {
    title: state.title,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: state.selectedAudience,
  };

  if (currentTemplate) {
    payload.message = parserData?.renderedTemplate || '';
    payload.template_params = {
      name: currentTemplate.name || '',
      namespace: currentTemplate.namespace || '',
      category: currentTemplate.category || 'UTILITY',
      language: currentTemplate.language || 'en_US',
      processed_params: parserData?.processedParams || {},
    };
  } else {
    payload.message = state.message;
  }

  return payload;
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

// Reset template selection when inbox changes
watch(
  () => state.inboxId,
  () => {
    state.templateId = null;
  }
);

watch(
  () => state.selectedAudience,
  newAudience => {
    clearTimeout(previewDebounceTimer);
    previewDebounceTimer = setTimeout(
      () => fetchContactsPreview(newAudience),
      500
    );
  }
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
        <span class="text-n-slate-10 font-normal">(opcional)</span>
      </label>
      <ComboBox
        id="template"
        v-model="state.templateId"
        :options="templateOptions"
        :placeholder="
          templateOptions.length
            ? t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')
            : 'Nenhum template disponível'
        "
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.INFO') }}
      </p>
    </div>

    <!-- Template Parser (when template is selected) -->
    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
    />

    <!-- Fallback message textarea (when no template is selected) -->
    <div v-if="!selectedTemplate" class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        Mensagem
      </label>
      <textarea
        v-model="state.message"
        rows="4"
        placeholder="Digite a mensagem da campanha..."
        class="w-full rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-9 outline-none focus:border-n-brand resize-none"
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
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
