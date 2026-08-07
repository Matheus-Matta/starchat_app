<script setup>
import { reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { isPhoneE164OrEmpty, isNumber } from 'shared/helpers/Validators';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  channelId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['migrated']);

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const isSubmitting = ref(false);

const state = reactive({
  phoneNumber: '',
  apiKey: '',
  phoneNumberId: '',
  businessAccountId: '',
});

const rules = {
  phoneNumber: { required, isPhoneE164OrEmpty },
  apiKey: { required },
  phoneNumberId: { required, isNumber },
  businessAccountId: { required, isNumber },
};

const v$ = useVuelidate(rules, state);

const resetForm = () => {
  state.phoneNumber = '';
  state.apiKey = '';
  state.phoneNumberId = '';
  state.businessAccountId = '';
  v$.value.$reset();
};

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();

const handleClose = () => {
  resetForm();
};

const handleConfirm = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  isSubmitting.value = true;
  try {
    const response = await store.dispatch('evolution/migrateToWhatsapp', {
      id: props.channelId,
      whatsappChannel: {
        phone_number: state.phoneNumber,
        api_key: state.apiKey,
        phone_number_id: state.phoneNumberId,
        business_account_id: state.businessAccountId,
      },
    });

    useAlert(t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.SUCCESS'));
    if (response?.needs_reauthorization) {
      useAlert(t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.NEEDS_REAUTH'));
    }

    emit('migrated', response);
    close();
  } catch (error) {
    const errorMessage =
      parseAPIErrorResponse(error) ||
      t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.ERROR');
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="lg"
    :title="$t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.TITLE')"
    :description="$t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.WARNING')"
    :confirm-button-label="
      $t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.CONFIRM_BUTTON')
    "
    :is-loading="isSubmitting"
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="state.phoneNumber"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.LABEL')"
        :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.PLACEHOLDER')"
        :message="
          v$.phoneNumber.$error
            ? $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR')
            : ''
        "
        :message-type="v$.phoneNumber.$error ? 'error' : 'info'"
        @blur="v$.phoneNumber.$touch"
      />
      <Input
        v-model="state.phoneNumberId"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER_ID.LABEL')"
        :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER_ID.PLACEHOLDER')"
        :message="
          v$.phoneNumberId.$error
            ? $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER_ID.ERROR')
            : ''
        "
        :message-type="v$.phoneNumberId.$error ? 'error' : 'info'"
        @blur="v$.phoneNumberId.$touch"
      />
      <Input
        v-model="state.businessAccountId"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.BUSINESS_ACCOUNT_ID.LABEL')"
        :placeholder="
          $t('INBOX_MGMT.ADD.WHATSAPP.BUSINESS_ACCOUNT_ID.PLACEHOLDER')
        "
        :message="
          v$.businessAccountId.$error
            ? $t('INBOX_MGMT.ADD.WHATSAPP.BUSINESS_ACCOUNT_ID.ERROR')
            : ''
        "
        :message-type="v$.businessAccountId.$error ? 'error' : 'info'"
        @blur="v$.businessAccountId.$touch"
      />
      <Input
        v-model="state.apiKey"
        type="password"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.LABEL')"
        :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.PLACEHOLDER')"
        :message="
          v$.apiKey.$error ? $t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.ERROR') : ''
        "
        :message-type="v$.apiKey.$error ? 'error' : 'info'"
        @blur="v$.apiKey.$touch"
      />
    </div>
  </Dialog>
</template>
