<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const isFullBleed = computed(() => Boolean(route.meta.fullBleed));
const containerClass = computed(() =>
  isFullBleed.value ? 'max-w-[110rem] w-full pb-12' : 'max-w-[60rem] w-full pb-12'
);
const innerPaddingClass = computed(() => (isFullBleed.value ? 'px-0' : ''));
</script>

<template>
  <div class="reports--wrapper overflow-auto bg-n-background w-full px-6">
    <div :class="[containerClass, 'mx-auto', innerPaddingClass]">
      <router-view />
    </div>
  </div>
</template>
