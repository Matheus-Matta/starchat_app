<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const requireContactInboxMessaging = ref(false);
const isSubmitting = ref(false);

const { currentAccount, updateAccount } = useAccount();

watch(
  currentAccount,
  () => {
    const { require_contact_inbox_messaging } =
      currentAccount.value?.settings || {};

    requireContactInboxMessaging.value = !!require_contact_inbox_messaging;
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async settings => {
  try {
    isSubmitting.value = true;
    await updateAccount(settings, { silent: true });
    useAlert(t('GENERAL_SETTINGS.UPDATE.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.UPDATE.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleSubmit = async () => {
  return updateAccountSettings({
    require_contact_inbox_messaging: requireContactInboxMessaging.value,
  });
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.MESSAGING_PREFERENCES.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.MESSAGING_PREFERENCES.NOTE')"
  >
    <form class="grid gap-5" @submit.prevent="handleSubmit">
      <div
        class="rounded-xl border border-n-weak bg-n-solid-1 w-full text-sm text-n-slate-12 divide-y divide-n-weak"
      >
        <div class="p-3 h-auto flex items-center justify-between">
          <div class="flex flex-col gap-0.5 max-w-[80%] py-1">
            <span>
              {{
                t(
                  'GENERAL_SETTINGS.FORM.MESSAGING_PREFERENCES.REQUIRE_CONTACT_INBOX_MESSAGING.LABEL'
                )
              }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                t(
                  'GENERAL_SETTINGS.FORM.MESSAGING_PREFERENCES.REQUIRE_CONTACT_INBOX_MESSAGING.HELP'
                )
              }}
            </span>
          </div>
          <Switch v-model="requireContactInboxMessaging" />
        </div>
      </div>
      <div class="flex gap-2">
        <NextButton
          blue
          type="submit"
          :is-loading="isSubmitting"
          :label="
            t('GENERAL_SETTINGS.FORM.MESSAGING_PREFERENCES.UPDATE_BUTTON')
          "
        />
      </div>
    </form>
  </SectionLayout>
</template>
