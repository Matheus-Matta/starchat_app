<script setup>
import { useAccount } from 'dashboard/composables/useAccount';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import AssistantCard from 'dashboard/components-next/cosmos/assistant/AssistantCard.vue';
import FeatureSpotlight from 'dashboard/components-next/feature-spotlight/FeatureSpotlight.vue';
import { assistantsList } from 'dashboard/components-next/cosmos/pageComponents/emptyStates/cosmosEmptyStateContent.js';

const emit = defineEmits(['click']);
const { isOnStarchatsCloud } = useAccount();

const onClick = () => {
  emit('click');
};
</script>

<template>
  <FeatureSpotlight
    :title="$t('COSMOS.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.TITLE')"
    :note="$t('COSMOS.ASSISTANTS.EMPTY_STATE.FEATURE_SPOTLIGHT.NOTE')"
    fallback-thumbnail="/assets/images/dashboard/cosmos/assistant-light.svg"
    fallback-thumbnail-dark="/assets/images/dashboard/cosmos/assistant-dark.svg"
    learn-more-url="https://chwt.app/cosmos-assistant"
    class="mb-8"
    :hide-actions="!isOnStarchatsCloud"
  />
  <EmptyStateLayout
    :title="$t('COSMOS.ASSISTANTS.EMPTY_STATE.TITLE')"
    :subtitle="$t('COSMOS.ASSISTANTS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="grid grid-cols-1 gap-4 p-px overflow-hidden">
        <AssistantCard
          v-for="(assistant, index) in assistantsList.slice(0, 5)"
          :id="assistant.id"
          :key="`assistant-${index}`"
          :name="assistant.name"
          :description="assistant.description"
          :updated-at="assistant.created_at"
        />
      </div>
    </template>
    <template #actions>
      <Button
        :label="$t('COSMOS.ASSISTANTS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>
