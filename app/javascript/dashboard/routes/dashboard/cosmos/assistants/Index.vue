<script setup>
import { computed, ref, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';

import PageLayout from 'dashboard/components-next/cosmos/PageLayout.vue';
import CosmosPaywall from 'dashboard/components-next/cosmos/pageComponents/Paywall.vue';
import CreateAssistantDialog from 'dashboard/components-next/cosmos/pageComponents/assistant/CreateAssistantDialog.vue';
import AssistantPageEmptyState from 'dashboard/components-next/cosmos/pageComponents/emptyStates/AssistantPageEmptyState.vue';
import FeatureSpotlightPopover from 'dashboard/components-next/feature-spotlight/FeatureSpotlightPopover.vue';

const { isOnChatwootCloud } = useAccount();

const dialogType = ref('');
const uiFlags = useMapGetter('cosmosAssistants/getUIFlags');
const isFetching = computed(() => uiFlags.value.fetchingList);

const selectedAssistant = ref(null);
const createAssistantDialog = ref(null);
const router = useRouter();

const handleCreate = () => {
  dialogType.value = 'create';
  nextTick(() => createAssistantDialog.value.dialogRef.open());
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedAssistant.value = null;
};

const handleAfterCreate = newAssistant => {
  // Navigate directly to documents page with the new assistant ID
  if (newAssistant?.id) {
    router.push({
      name: 'cosmos_assistants_responses_index',
      params: {
        accountId: router.currentRoute.value.params.accountId,
        assistantId: newAssistant.id,
      },
    });
  }
};
</script>

<template>
  <PageLayout
    :header-title="$t('COSMOS.ASSISTANTS.HEADER')"
    :show-pagination-footer="false"
    :is-fetching="isFetching"
    :feature-flag="FEATURE_FLAGS.COSMOS"
    is-empty
    @click="handleCreate"
  >
    <template #knowMore>
      <FeatureSpotlightPopover
        :button-label="$t('COSMOS.HEADER_KNOW_MORE')"
        :title="$t('COSMOS.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
        :note="$t('COSMOS.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
        :hide-actions="!isOnChatwootCloud"
        fallback-thumbnail="/assets/images/dashboard/cosmos/assistant-popover-light.svg"
        fallback-thumbnail-dark="/assets/images/dashboard/cosmos/assistant-popover-dark.svg"
        learn-more-url="https://chwt.app/cosmos-assistant"
      />
    </template>
    <template #emptyState>
      <AssistantPageEmptyState @click="handleCreate" />
    </template>

    <template #paywall>
      <CosmosPaywall />
    </template>

    <CreateAssistantDialog
      v-if="dialogType"
      ref="createAssistantDialog"
      :type="dialogType"
      :selected-assistant="selectedAssistant"
      @close="handleCreateClose"
      @created="handleAfterCreate"
    />
  </PageLayout>
</template>
