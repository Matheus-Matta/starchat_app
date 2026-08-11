<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';
import ButtonV4 from 'next/button/Button.vue';
import whatsappChannel from 'dashboard/api/channel/whatsappChannel';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from './utils';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
  whatsappRegistrationIncomplete: {
    type: Boolean,
    default: false,
  },
  showAsReconnectButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();

const isRequestingAuthorization = ref(false);
const isLoadingFacebook = ref(true);

const whatsappAppId = computed(() => window.starchatsConfig.whatsappAppId);
const whatsappConfigurationId = computed(
  () => window.starchatsConfig.whatsappConfigurationId
);

const actionLabel = computed(() => {
  if (props.whatsappRegistrationIncomplete) {
    return t('INBOX_MGMT.COMPLETE_REGISTRATION');
  }
  return '';
});

const description = computed(() => {
  if (props.whatsappRegistrationIncomplete) {
    return t('INBOX_MGMT.WHATSAPP_REGISTRATION_INCOMPLETE');
  }
  return '';
});

const reauthorizeWhatsApp = async params => {
  isRequestingAuthorization.value = true;

  try {
    const response = await whatsappChannel.reauthorizeWhatsApp({
      inboxId: props.inbox.id,
      ...params,
    });

    if (response.data.success) {
      useAlert(t('INBOX.REAUTHORIZE.SUCCESS'));
    } else {
      useAlert(response.data.message || t('INBOX.REAUTHORIZE.ERROR'));
    }
  } catch (error) {
    useAlert(error.message || t('INBOX.REAUTHORIZE.ERROR'));
  } finally {
    isRequestingAuthorization.value = false;
  }
};

const handleEmbeddedSignupEvents = async (data, authCode) => {
  if (!data || typeof data !== 'object') {
    return;
  }

  // Handle different event types
  if (data.event === 'FINISH') {
    const businessData = data.data;

    if (isValidBusinessData(businessData) && businessData.phone_number_id) {
      await reauthorizeWhatsApp({
        code: authCode,
        business_id: businessData.business_id,
        waba_id: businessData.waba_id,
        phone_number_id: businessData.phone_number_id,
      });
    } else {
      useAlert(
        t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.INVALID_BUSINESS_DATA')
      );
    }
  } else if (data.event === 'CANCEL') {
    isRequestingAuthorization.value = false;
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
  } else if (data.event === 'error') {
    isRequestingAuthorization.value = false;
    useAlert(
      data.error_message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.SIGNUP_ERROR')
    );
  }
};

const startEmbeddedSignup = authCode => {
  const messageHandler = createMessageHandler(data =>
    handleEmbeddedSignupEvents(data, authCode)
  );
  window.addEventListener('message', messageHandler);
};

const handleLoginAndReauthorize = async () => {
  // Validate required configuration
  if (!whatsappAppId.value) {
    throw new Error('WhatsApp App ID is required');
  }
  if (!whatsappConfigurationId.value) {
    throw new Error('WhatsApp Configuration ID is required');
  }

  try {
    const authCode = await initWhatsAppEmbeddedSignup(
      whatsappConfigurationId.value
    );

    // Check if this is a reauthorization scenario where we already have the business data
    const existingConfig = props.inbox.provider_config;
    if (
      existingConfig &&
      existingConfig.business_account_id &&
      existingConfig.phone_number_id
    ) {
      await reauthorizeWhatsApp({
        code: authCode,
        business_id: existingConfig.business_account_id,
        waba_id: existingConfig.business_account_id,
        phone_number_id: existingConfig.phone_number_id,
      });
    } else {
      startEmbeddedSignup(authCode);
    }
  } catch (error) {
    if (error.message === 'Login cancelled') {
      useAlert(t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.CANCELLED'));
    } else {
      useAlert(
        error.message ||
          t('INBOX_MGMT.ADD.WHATSAPP.EMBEDDED_SIGNUP.AUTH_NOT_COMPLETED')
      );
    }
    throw error;
  }
};

const requestAuthorization = async () => {
  if (isLoadingFacebook.value) {
    useAlert(t('INBOX.REAUTHORIZE.LOADING_FACEBOOK'));
    return;
  }

  isRequestingAuthorization.value = true;
  try {
    await handleLoginAndReauthorize();
  } catch (error) {
    useAlert(error.message || t('INBOX.REAUTHORIZE.CONFIGURATION_ERROR'));
  } finally {
    // Reset only if not already processing through embedded signup
    if (!window.FB || !window.FB.getLoginStatus) {
      isRequestingAuthorization.value = false;
    }
  }
};

onMounted(async () => {
  try {
    if (!whatsappAppId.value || !whatsappConfigurationId.value) {
      return;
    }

    await setupFacebookSdk(
      whatsappAppId.value,
      window.starchatsConfig?.whatsappApiVersion
    );
  } catch {
    // SDK load failure will surface when the user clicks the reconnect button
  } finally {
    isLoadingFacebook.value = false;
  }
});

// Expose requestAuthorization function for parent components
defineExpose({
  requestAuthorization,
});
</script>

<template>
  <InboxReconnectionRequired
    v-if="!showAsReconnectButton"
    class="mx-6"
    :is-loading="isRequestingAuthorization"
    :action-label="actionLabel"
    :description="description"
    @reauthorize="requestAuthorization"
  />
  <div
    v-else
    class="mx-6 px-5 py-5 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak bg-n-solid-2"
  >
    <div
      class="flex flex-col gap-5 justify-between items-start w-full md:flex-row"
    >
      <div>
        <span class="text-heading-3 text-n-slate-12">
          {{ t('INBOX.RECONNECT.TITLE') }}
        </span>
        <p class="mt-1 text-body-main text-n-slate-11">
          {{ t('INBOX.RECONNECT.DESCRIPTION') }}
        </p>
      </div>
      <ButtonV4
        sm
        solid
        blue
        class="flex-shrink-0"
        :loading="isRequestingAuthorization"
        :disabled="isRequestingAuthorization || isLoadingFacebook"
        @click="requestAuthorization"
      >
        {{ t('INBOX.RECONNECT.BUTTON_TEXT') }}
      </ButtonV4>
    </div>
  </div>
</template>
