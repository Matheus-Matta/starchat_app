<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from './provider.js';
import { hasOneDayPassed } from 'shared/helpers/timeHelper';
import { ORIENTATION, MESSAGE_STATUS } from './constants';

defineProps({
  error: { type: String, required: true },
});

const emit = defineEmits(['retry']);

const { orientation, status, createdAt } = useMessageContext();

const { t } = useI18n();

const canRetry = computed(() => !hasOneDayPassed(createdAt.value));
</script>

<template>
  <div
    class="text-xs text-n-ruby-11 flex flex-col gap-1"
    :class="orientation === ORIENTATION.LEFT ? 'items-start' : 'items-end'"
  >
    <div class="flex items-center gap-1.5">
      <div class="relative group">
        <div
          class="bg-n-alpha-2 rounded-md size-5 grid place-content-center cursor-pointer"
        >
          <Icon
            icon="i-lucide-alert-triangle"
            class="text-n-ruby-11 size-[14px]"
          />
        </div>
      </div>
      <span>{{ t('CHAT_LIST.FAILED_TO_SEND') }}</span>
      <button
        v-if="canRetry"
        type="button"
        :disabled="status !== MESSAGE_STATUS.FAILED"
        class="bg-n-alpha-2 rounded-md size-5 grid place-content-center cursor-pointer hover:bg-n-alpha-3 transition-colors"
        @click="emit('retry')"
      >
        <Icon icon="i-lucide-refresh-ccw" class="text-n-ruby-11 size-[14px]" />
      </button>
    </div>
    <div
      v-if="error"
      class="text-xs font-medium max-w-[250px] break-words"
      :class="[
        orientation === ORIENTATION.LEFT ? 'text-left' : 'text-right',
        error.toLowerCase().includes('frequência') ||
        error.toLowerCase().includes('frequently')
          ? 'text-n-amber-11'
          : 'bg-n-alpha-2 text-n-ruby-12 px-2 py-1.5 rounded-md border border-n-ruby-6',
      ]"
    >
      {{ error }}
    </div>
  </div>
</template>
