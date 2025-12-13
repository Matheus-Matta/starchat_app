<script setup>
import { ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  title: { type: String, default: '' },
  note: { type: String, default: '' },
  videoUrl: { type: String, default: '' },
  thumbnail: { type: String, default: '' },
  fallbackThumbnail: { type: String, default: '' },
  fallbackThumbnailDark: { type: String, default: '' },
  learnMoreUrl: { type: String, default: '' },
  hideActions: { type: Boolean, default: false },
});

const imageError = ref(false);

const handleImageError = () => {
  imageError.value = true;
};

const openLink = link => {
  if (link) {
    window.open(link, '_blank');
  }
};
</script>

<template>
  <section style="" class="" />
</template>
