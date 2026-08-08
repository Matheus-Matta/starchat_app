<script setup>
import { reactive, ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { requiredIf } from '@vuelidate/validators';
import { isPhoneE164OrEmpty, isNumber } from 'shared/helpers/Validators';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from '../channels/whatsapp/utils';

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
const isOpen = ref(false);
const isSubmitting = ref(false);

// Embedded signup is only offered when the installation has the Meta app
// configured; otherwise the manual credentials form is the only option.
const hasEmbeddedSignup = computed(() => {
  const { whatsappAppId, whatsappConfigurationId } =
    window.chatwootConfig || {};
  return Boolean(
    whatsappAppId && whatsappAppId !== 'none' && whatsappConfigurationId
  );
});

const preferManualCredentials = ref(false);
const isManualMode = computed(
  () => preferManualCredentials.value || !hasEmbeddedSignup.value
);

const state = reactive({
  phoneNumber: '',
  apiKey: '',
  phoneNumberId: '',
  businessAccountId: '',
});

const rules = {
  phoneNumber: { required: requiredIf(isManualMode), isPhoneE164OrEmpty },
  apiKey: { required: requiredIf(isManualMode) },
  phoneNumberId: { required: requiredIf(isManualMode), isNumber },
  businessAccountId: { required: requiredIf(isManualMode), isNumber },
};

const v$ = useVuelidate(rules, state);

// Embedded signup handshake state: Meta delivers the authorization code and the
// business data through two independent channels, so we migrate once both land.
const authCode = ref(null);
const businessData = ref(null);
const isAuthenticating = ref(false);

const resetEmbeddedState = () => {
  authCode.value = null;
  businessData.value = null;
  isAuthenticating.value = false;
};

const resetForm = () => {
  state.phoneNumber = '';
  state.apiKey = '';
  state.phoneNumberId = '';
  state.businessAccountId = '';
  v$.value.$reset();
  preferManualCredentials.value = false;
  resetEmbeddedState();
};

const open = () => {
  isOpen.value = true;
  dialogRef.value?.open();
};
const close = () => {
  isOpen.value = false;
  dialogRef.value?.close();
};

const handleClose = () => {
  isOpen.value = false;
  resetForm();
};

const runMigration = async whatsappChannel => {
  isSubmitting.value = true;
  try {
    const response = await store.dispatch('evolution/migrateToWhatsapp', {
      id: props.channelId,
      whatsappChannel,
    });

    useAlert(t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.SUCCESS'));
    if (response?.needs_reauthorization) {
      useAlert(t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.NEEDS_REAUTH'));
    }

    emit('migrated', response);
    close();
    return true;
  } catch (error) {
    const errorMessage =
      parseAPIErrorResponse(error) ||
      t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.ERROR');
    useAlert(errorMessage);
    return false;
  } finally {
    isSubmitting.value = false;
  }
};

const handleConfirm = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  await runMigration({
    phone_number: state.phoneNumber,
    api_key: state.apiKey,
    phone_number_id: state.phoneNumberId,
    business_account_id: state.businessAccountId,
  });
};

const migrateWithEmbeddedSignup = async () => {
  isAuthenticating.value = false;
  const migrated = await runMigration({
    code: authCode.value,
    business_id: businessData.value.business_id,
    waba_id: businessData.value.waba_id,
    phone_number_id: businessData.value.phone_number_id || '',
  });

  // The code is single-use, so a failed attempt has to restart the handshake.
  resetEmbeddedState();
  return migrated;
};

const handleEmbeddedSignupData = async data => {
  if (!isOpen.value) return;

  if (
    data.event === 'FINISH' ||
    data.event === 'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING'
  ) {
    if (!isValidBusinessData(data.data)) {
      isAuthenticating.value = false;
      useAlert(
        t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.INVALID_BUSINESS_DATA')
      );
      return;
    }

    businessData.value = data.data;
    if (authCode.value) await migrateWithEmbeddedSignup();
  } else if (data.event === 'CANCEL') {
    resetEmbeddedState();
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
  } else if (data.event === 'error') {
    resetEmbeddedState();
    useAlert(
      data.error_message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SIGNUP_ERROR')
    );
  }
};

const handleSignupMessage = createMessageHandler(handleEmbeddedSignupData);

const launchEmbeddedSignup = async () => {
  isAuthenticating.value = true;
  try {
    await setupFacebookSdk(
      window.chatwootConfig?.whatsappAppId,
      window.chatwootConfig?.whatsappApiVersion
    );

    authCode.value = await initWhatsAppEmbeddedSignup(
      window.chatwootConfig?.whatsappConfigurationId
    );

    if (businessData.value) await migrateWithEmbeddedSignup();
  } catch (error) {
    resetEmbeddedState();
    if (error.message === 'Login cancelled') {
      useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
    } else {
      useAlert(
        error.message ||
          t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SDK_LOAD_ERROR')
      );
    }
  }
};

const dialogDescription = computed(() =>
  isManualMode.value
    ? t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.WARNING')
    : t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.WARNING_EMBEDDED')
);

onMounted(() => window.addEventListener('message', handleSignupMessage));
onBeforeUnmount(() =>
  window.removeEventListener('message', handleSignupMessage)
);

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    width="lg"
    :title="$t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.TITLE')"
    :description="dialogDescription"
    :confirm-button-label="
      $t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.CONFIRM_BUTTON')
    "
    :show-confirm-button="isManualMode"
    :is-loading="isSubmitting"
    @confirm="handleConfirm"
    @close="handleClose"
  >
    <div v-if="!isManualMode" class="flex flex-col gap-4">
      <NextButton
        faded
        slate
        class="w-full"
        :is-loading="isAuthenticating || isSubmitting"
        :disabled="isAuthenticating || isSubmitting"
        :label="$t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.EMBEDDED_BUTTON')"
        @click="launchEmbeddedSignup"
      />
      <button
        type="button"
        class="text-sm underline text-n-slate-11 hover:text-n-slate-12"
        @click="preferManualCredentials = true"
      >
        {{ $t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.MANUAL_LINK') }}
      </button>
    </div>

    <div v-else class="flex flex-col gap-4">
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
      <button
        v-if="hasEmbeddedSignup"
        type="button"
        class="text-sm underline text-n-slate-11 hover:text-n-slate-12 self-start"
        @click="preferManualCredentials = false"
      >
        {{ $t('INBOX_MGMT.ADD.EVOLUTION.MIGRATE.EMBEDDED_LINK') }}
      </button>
    </div>
  </Dialog>
</template>
