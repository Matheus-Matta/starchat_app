<script setup>
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import { onMounted } from 'vue';
import { getSupportWidget } from 'dashboard/helper/supportWidget';

const toggleSupportWidgetVisibility = () => {
  getSupportWidget()?.toggleBubbleVisibility('show');
};

const setupListenerForWidgetEvent = () => {
  window.addEventListener('starchats:on-message', () => {
    toggleSupportWidgetVisibility();
  });
};

onMounted(() => {
  toggleSupportWidgetVisibility();
  setupListenerForWidgetEvent();
});
</script>

<template>
  <div class="items-center bg-n-slate-2 flex justify-center h-full w-full">
    <EmptyState
      :title="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.TITLE')"
      :message="$t('APP_GLOBAL.ACCOUNT_SUSPENDED.MESSAGE')"
    />
  </div>
</template>
