<script setup>
import { ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  buttonLabel: { type: String, default: '' },
  note: { type: String, default: '' },
});

const [isPopupVisible, togglePopup] = useToggle();
</script>

<template>
  <div class="relative">
    <Button
      id="togglePopup"
      :label="buttonLabel"
      slate
      ghost
      sm
      :class="{ 'bg-n-alpha-2': isPopupVisible }"
      @click="togglePopup(!isPopupVisible)"
    />

    <div
      v-if="isPopupVisible"
      v-on-click-outside="[
        () => isPopupVisible && (isPopupVisible = false),
        { ignore: ['#togglePopup'] },
      ]"
    >
      <section
        class="absolute top-full mt-6 ltr:left-0 rtl:right-0 outline outline-1 outline-n-weak bg-n-alpha-3 backdrop-blur-[100px] rounded-xl p-4 w-80"
      >
        <div
          class="absolute -top-[0.77rem] ltr:left-12 rtl:right-12 w-6 h-6 ltr:rotate-45 rtl:-rotate-45 rtl:rounded-tr ltr:rounded-tl rtl:border-r ltr:border-l border-t border-n-weak bg-n-alpha-3 z-10"
        />

        <div class="relative flex flex-col items-start gap-4 z-20">
          <p v-if="note" class="text-n-slate-12 text-start text-sm mb-0">
            {{ note }}
          </p>
        </div>
      </section>
    </div>
  </div>
</template>
