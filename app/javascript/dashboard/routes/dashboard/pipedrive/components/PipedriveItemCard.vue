<script setup>
import { useI18n } from 'vue-i18n';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: 'i-lucide-box' },
  pipedriveLink: { type: String, default: '' },
  isExpanded: { type: Boolean, default: false },
});

const emit = defineEmits(['toggle']);

const { t } = useI18n();

const openPipedriveLink = () => {
  if (props.pipedriveLink) {
    window.open(props.pipedriveLink, '_blank');
  }
};
</script>

<template>
  <div class="relative">
    <CardLayout layout="row">
      <div class="flex items-center justify-start flex-1 gap-4">
        <!-- Avatar/Icon -->
        <div
          class="size-12 min-h-[48px] min-w-[48px] rounded-full flex items-center justify-center bg-n-alpha-2 text-n-slate-11 border border-n-weak"
        >
          <span :class="icon" class="size-6" />
        </div>

        <div class="flex flex-col gap-0.5 flex-1 max-w-[calc(100%-64px)]">
          <div class="flex flex-wrap items-center gap-x-4">
            <span class="text-base font-medium truncate text-n-slate-12">
              {{ title }}
            </span>
          </div>

          <div
            class="flex flex-wrap items-center justify-start gap-x-3 gap-y-1"
          >
            <span class="text-sm text-n-slate-11 truncate">
              {{ subtitle }}
            </span>
            <div v-if="pipedriveLink" class="w-px h-3 truncate bg-n-slate-6" />
            <Button
              v-if="pipedriveLink"
              :label="t('INTEGRATION_SETTINGS.PIPEDRIVE.VIEW_FULL_DETAILS')"
              variant="link"
              size="xs"
              @click="openPipedriveLink"
            />
          </div>
        </div>
      </div>

      <Button
        icon="i-lucide-chevron-down"
        variant="ghost"
        color="slate"
        size="xs"
        :class="{ 'rotate-180': isExpanded }"
        @click="emit('toggle')"
      />

      <template #after>
        <div
          class="transition-all duration-500 ease-in-out grid overflow-hidden rounded-b-md"
          :class="
            isExpanded
              ? 'grid-rows-[1fr] opacity-100'
              : 'grid-rows-[0fr] opacity-0'
          "
        >
          <div class="overflow-hidden">
            <div class="border-t border-n-strong">
              <slot name="content" />
            </div>
          </div>
        </div>
      </template>
    </CardLayout>
  </div>
</template>
