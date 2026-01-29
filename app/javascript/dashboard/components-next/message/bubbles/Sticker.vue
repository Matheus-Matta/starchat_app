<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../provider.js';

const emit = defineEmits(['error']);

const { attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const hasError = ref(false);

const handleError = () => {
  hasError.value = true;
  emit('error');
};
</script>

<template>
  <BaseBubble
    class="!bg-transparent !p-0 shadow-none hover:shadow-none"
    data-bubble-name="sticker"
  >
    <div
      v-if="hasError"
      class="flex items-center gap-1 text-center rounded-lg bg-n-slate-4 p-3"
    >
      <Icon icon="i-lucide-circle-off" class="text-n-slate-11" />
      <p class="mb-0 text-n-slate-11">Media unavailable</p>
    </div>
    <div v-else class="relative group">
      <img
        class="skip-context-menu max-w-[160px] max-h-[160px] object-contain"
        :src="attachment.dataUrl"
        :alt="attachment.title || 'Sticker'"
        @error="handleError"
      />
    </div>
  </BaseBubble>
</template>
