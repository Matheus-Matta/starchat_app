<script setup>
import { computed, reactive } from 'vue';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

const router = useRouter();
const store = useStore();
const { t } = useI18n();

const form = reactive({
  name: '',
  phoneNumber: '',
  wabaId: '',
  apiKey: '',
  webhookSecret: '',
});

const uiFlags = computed(() => store.getters['inboxes/getUIFlags']);
const webhookUrl = computed(() => `${window.location.origin}/webhooks/ycloud`);
const isValid = computed(() => {
  const allFieldsPresent = Object.values(form).every(value => value.trim());
  return allFieldsPresent && /^\+[1-9]\d{6,14}$/.test(form.phoneNumber.trim());
});

const createChannel = async () => {
  if (!isValid.value) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.REQUIRED_FIELDS'));
    return;
  }

  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: form.name.trim(),
      channel: {
        type: 'whatsapp',
        provider: 'ycloud',
        phone_number: form.phoneNumber.trim(),
        provider_config: {
          api_key: form.apiKey.trim(),
          waba_id: form.wabaId.trim(),
          webhook_secret: form.webhookSecret.trim(),
        },
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inbox.id },
    });
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="createChannel">
    <div>
      <h3 class="text-base font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.TITLE') }}
      </h3>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.DESCRIPTION') }}
      </p>
    </div>

    <label
      v-for="field in [
        ['name', 'INBOX_NAME'],
        ['phoneNumber', 'PHONE_NUMBER'],
        ['wabaId', 'WABA_ID'],
        ['apiKey', 'API_KEY'],
        ['webhookSecret', 'WEBHOOK_SECRET'],
      ]"
      :key="field[0]"
    >
      {{ $t(`INBOX_MGMT.ADD.WHATSAPP.YCLOUD.${field[1]}`) }}
      <input
        v-model="form[field[0]]"
        class="block w-full px-3 py-2 mt-1 text-sm border rounded-lg outline-none bg-n-alpha-1 border-n-weak text-n-slate-12 focus:border-n-brand"
        :type="
          field[0].includes('Key') || field[0].includes('Secret')
            ? 'password'
            : 'text'
        "
      />
    </label>

    <div class="p-3 rounded-lg bg-n-alpha-2">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.WEBHOOK_URL') }}
      </p>
      <code class="text-sm break-all text-n-slate-11">{{ webhookUrl }}</code>
      <p class="mt-2 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.WEBHOOK_INSTRUCTION') }}
      </p>
    </div>

    <NextButton
      type="submit"
      :label="$t('INBOX_MGMT.ADD.WHATSAPP.YCLOUD.SUBMIT')"
      :is-loading="uiFlags.isCreating"
    />
  </form>
</template>
