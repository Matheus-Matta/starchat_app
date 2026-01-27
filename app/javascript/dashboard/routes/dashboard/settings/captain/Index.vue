<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCosmos } from 'dashboard/composables/useCosmos';
import { useConfig } from 'dashboard/composables/useConfig';
import { useCosmosConfigStore } from 'dashboard/store/cosmos/preferences';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import ModelSelector from './components/ModelSelector.vue';
import FeatureToggle from './components/FeatureToggle.vue';
import CosmosPaywall from 'next/cosmos/pageComponents/Paywall.vue';

const { t } = useI18n();
const { cosmosEnabled } = useCosmos();
const { isEnterprise, enterprisePlanName } = useConfig();
const { isOnChatwootCloud } = useAccount();

const cosmosConfigStore = useCosmosConfigStore();
const { uiFlags } = storeToRefs(cosmosConfigStore);

const isLoading = computed(() => uiFlags.value.isFetching);

const modelFeatures = computed(() => [
  {
    key: 'editor',
    title: t('COSMOS_SETTINGS.MODEL_CONFIG.EDITOR.TITLE'),
    description: t('COSMOS_SETTINGS.MODEL_CONFIG.EDITOR.DESCRIPTION'),
  },
  {
    key: 'assistant',
    title: t('COSMOS_SETTINGS.MODEL_CONFIG.ASSISTANT.TITLE'),
    description: t('COSMOS_SETTINGS.MODEL_CONFIG.ASSISTANT.DESCRIPTION'),
    enterprise: true,
  },
  {
    key: 'copilot',
    title: t('COSMOS_SETTINGS.MODEL_CONFIG.COPILOT.TITLE'),
    description: t('COSMOS_SETTINGS.MODEL_CONFIG.COPILOT.DESCRIPTION'),
    enterprise: true,
  },
]);

const featureToggles = computed(() => [
  {
    key: 'label_suggestion',
  },
  {
    key: 'help_center_search',
    enterprise: true,
  },
  {
    key: 'audio_transcription',
    enterprise: true,
  },
]);

const shouldShowFeature = feature => {
  // Cloud will always see these features as long as cosmos is enabled
  if (isOnChatwootCloud.value && cosmosEnabled) {
    return true;
  }

  if (feature.enterprise) {
    // if the app is in enterprise mode, then we can show the feature
    // this is not the installation plan, but when the enterprise folder is missing
    return isEnterprise;
  }

  return true;
};

const isFeatureAccessible = feature => {
  // Cloud will always see these features as long as cosmos is enabled
  if (isOnChatwootCloud.value && cosmosEnabled) {
    return true;
  }

  if (feature.enterprise) {
    // plan is shown, but is it accessible?
    // This ensures that the instance has purchased the enterprise license, and only then we allow
    // access
    return isEnterprise && enterprisePlanName === 'enterprise';
  }

  return true;
};

async function handleFeatureToggle({ feature, enabled }) {
  try {
    await cosmosConfigStore.updatePreferences({
      cOSMOS_features: { [feature]: enabled },
    });
    useAlert(t('COSMOS_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('COSMOS_SETTINGS.API.ERROR'));
    cosmosConfigStore.fetch();
  }
}

async function handleModelChange({ feature, model }) {
  try {
    await cosmosConfigStore.updatePreferences({
      cOSMOS_models: { [feature]: model },
    });
    useAlert(t('COSMOS_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('COSMOS_SETTINGS.API.ERROR'));
    cosmosConfigStore.fetch();
  }
}

onMounted(() => {
  cosmosConfigStore.fetch();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :no-records-message="t('COSMOS_SETTINGS.NOT_ENABLED')"
    :loading-message="t('COSMOS_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('COSMOS_SETTINGS.TITLE')"
        :description="t('COSMOS_SETTINGS.DESCRIPTION')"
        :link-text="t('COSMOS_SETTINGS.LINK_TEXT')"
        icon-name="cosmos"
        feature-name="cosmos_billing"
      />
    </template>
    <template #body>
      <div v-if="cosmosEnabled" class="flex flex-col gap-1">
        <!-- Model Configuration Section -->
        <SectionLayout
          :title="t('COSMOS_SETTINGS.MODEL_CONFIG.TITLE')"
          :description="t('COSMOS_SETTINGS.MODEL_CONFIG.DESCRIPTION')"
        >
          <div class="grid gap-4">
            <ModelSelector
              v-for="feature in modelFeatures"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              :title="feature.title"
              :description="feature.description"
              @change="handleModelChange"
            />
          </div>
        </SectionLayout>

        <!-- Features Section -->
        <SectionLayout
          :title="t('COSMOS_SETTINGS.FEATURES.TITLE')"
          :description="t('COSMOS_SETTINGS.FEATURES.DESCRIPTION')"
          with-border
        >
          <div class="grid gap-4">
            <FeatureToggle
              v-for="feature in featureToggles"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              @change="handleFeatureToggle"
              @model-change="handleModelChange"
            />
          </div>
        </SectionLayout>
      </div>
      <div v-else>
        <CosmosPaywall />
      </div>
    </template>
  </SettingsLayout>
</template>
