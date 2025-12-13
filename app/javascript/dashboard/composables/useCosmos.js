import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

export function useCosmos() {
  const store = useStore();
  const { isCloudFeatureEnabled, currentAccount } = useAccount();
  const { isEnterprise } = useConfig();

  const cosmosEnabled = computed(() => {
    return isCloudFeatureEnabled(FEATURE_FLAGS.COSMOS);
  });

  const cosmosLimits = computed(() => {
    return currentAccount.value?.limits?.cosmos;
  });

  const documentLimits = computed(() => {
    if (cosmosLimits.value?.documents) {
      return useCamelCase(cosmosLimits.value.documents);
    }

    return null;
  });

  const responseLimits = computed(() => {
    if (cosmosLimits.value?.responses) {
      return useCamelCase(cosmosLimits.value.responses);
    }

    return null;
  });

  const fetchLimits = () => {
    if (isEnterprise) {
      store.dispatch('accounts/limits');
    }
  };

  return {
    cosmosEnabled,
    cosmosLimits,
    documentLimits,
    responseLimits,
    fetchLimits,
  };
}
