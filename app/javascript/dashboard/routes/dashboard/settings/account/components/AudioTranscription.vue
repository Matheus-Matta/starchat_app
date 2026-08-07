<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const { t } = useI18n();
const isEnabled = ref(false);
const provider = ref('whisper');

const { currentAccount, updateAccount, isCloudFeatureEnabled } = useAccount();

const isOpenaiAvailable = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.COSMOS)
);
const isWhisperAvailable = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.AUDIO_TRANSCRIPTION)
);

const providerOptions = computed(() =>
  [
    isWhisperAvailable.value && {
      value: 'whisper',
      label: t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.PROVIDER.WHISPER'),
    },
    isOpenaiAvailable.value && {
      value: 'openai',
      label: t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.PROVIDER.OPENAI'),
    },
  ].filter(Boolean)
);

watch(
  currentAccount,
  () => {
    const { audio_transcriptions, audio_transcription_provider } =
      currentAccount.value?.settings || {};
    isEnabled.value = !!audio_transcriptions;
    provider.value = audio_transcription_provider || 'whisper';
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async settings => {
  try {
    await updateAccount(settings);
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.API.ERROR'));
  }
};

const toggleAudioTranscription = async () => {
  return updateAccountSettings({
    audio_transcriptions: isEnabled.value,
  });
};

const updateProvider = async () => {
  return updateAccountSettings({
    audio_transcription_provider: provider.value,
  });
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.AUDIO_TRANSCRIPTION.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex items-center gap-3 justify-end">
        <Select
          v-if="isEnabled && providerOptions.length > 1"
          v-model="provider"
          :options="providerOptions"
          @change="updateProvider"
        />
        <Switch v-model="isEnabled" @change="toggleAudioTranscription" />
      </div>
    </template>
  </SectionLayout>
</template>
