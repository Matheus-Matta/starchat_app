<script setup>
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['click']);

const onClick = () => {
  emit('click');
};
</script>

<template>
  <EmptyStateLayout
    :title="$t('COSMOS.CUSTOM_TOOLS.EMPTY_STATE.TITLE')"
    :subtitle="$t('COSMOS.CUSTOM_TOOLS.EMPTY_STATE.SUBTITLE')"
    :action-perms="['administrator']"
  >
    <template #empty-state-item>
      <div class="min-h-[600px]" />
    </template>
    <template #actions>
      <Button
        :label="$t('COSMOS.CUSTOM_TOOLS.ADD_NEW')"
        icon="i-lucide-plus"
        @click="onClick"
      />
    </template>
  </EmptyStateLayout>
</template>
