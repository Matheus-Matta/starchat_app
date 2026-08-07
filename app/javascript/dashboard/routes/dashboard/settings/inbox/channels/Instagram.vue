<script>
import { useVuelidate } from '@vuelidate/core';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'vue-i18n';
import { ref, onMounted } from 'vue';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';
import instagramClient from 'dashboard/api/channel/instagramClient';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: { NextButton },
  mixins: [globalConfigMixin],
  setup() {
    const { accountId } = useAccount();
    const v$ = useVuelidate();
    const { t } = useI18n();

    const isCreating = ref(false);
    const hasError = ref(false);
    const errorStateMessage = ref('');
    const errorStateDescription = ref('');
    const isRequestingAuthorization = ref(false);

    onMounted(() => {
      const urlParams = new URLSearchParams(window.location.search);
      const errorCode = urlParams.get('code');
      const errorMessage = urlParams.get('error_message');

      if (errorMessage) {
        hasError.value = true;
        if (errorCode === '400') {
          errorStateMessage.value = errorMessage;
          errorStateDescription.value = t('INBOX_MGMT.ADD.INSTAGRAM.ERROR_AUTH');
        } else {
          errorStateMessage.value = t('INBOX_MGMT.ADD.INSTAGRAM.ERROR_MESSAGE');
          errorStateDescription.value = errorMessage;
        }
      }

      const cleanURL = window.location.pathname;
      window.history.replaceState({}, document.title, cleanURL);
    });

    const requestAuthorization = async () => {
      isRequestingAuthorization.value = true;
      const response = await instagramClient.generateAuthorization();
      const {
        data: { url },
      } = response;

      window.location.href = url;
    };

    // expose as $t to keep template usage consistent
    return {
      accountId,
      v$,
      $t: t,
      isCreating,
      hasError,
      errorStateMessage,
      errorStateDescription,
      isRequestingAuthorization,
      requestAuthorization,
    };
  }
};
</script>

<template>
  <div class="h-full p-6 w-full max-w-full flex-shrink-0 flex-grow-0">
    <div class="flex flex-col items-center justify-start h-full text-center">
      <div v-if="hasError" class="max-w-lg mx-auto text-center">
        <h5>{{ errorStateMessage }}</h5>
        <p
          v-if="errorStateDescription"
          v-dompurify-html="errorStateDescription"
        ></p>
      </div>
      <div
        v-else
        class="flex flex-col items-center justify-center px-8 py-10 text-center rounded-2xl outline outline-1 outline-n-weak"
      >
        <h6 class="text-2xl font-medium">
          {{ $t('INBOX_MGMT.ADD.INSTAGRAM.CONNECT_YOUR_INSTAGRAM_PROFILE') }}
        </h6>
        <p class="py-6 text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.INSTAGRAM.HELP') }}
        </p>
        <NextButton
          class="text-white !rounded-full !px-6 bg-gradient-to-r from-[#833AB4] via-[#FD1D1D] to-[#FCAF45]"
          lg
          icon="i-ri-instagram-line"
          :disabled="isRequestingAuthorization"
          :is-loading="isRequestingAuthorization"
          :label="$t('INBOX_MGMT.ADD.INSTAGRAM.CONTINUE_WITH_INSTAGRAM')"
          @click="requestAuthorization()"
        />
      </div>
    </div>
  </div>
</template>
