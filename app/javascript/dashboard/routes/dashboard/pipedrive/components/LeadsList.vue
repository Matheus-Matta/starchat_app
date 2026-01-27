<script setup>
import { defineProps } from 'vue';
import PipedriveLeadCard from './PipedriveLeadCard.vue';

defineProps({
  items: { type: Array, default: () => [] },
});
const emit = defineEmits(['refresh']);
</script>

<template>
  <div class="flex flex-col gap-2">
    <PipedriveLeadCard
      v-for="item in items"
      :key="item.id"
      :item="item"
      @refresh="emit('refresh')"
    />
    <div v-if="items.length === 0" class="text-center p-4 text-n-slate-11">
      {{ $t('CONTACTS_LAYOUT.NO_RECORDS_FOUND') }}
    </div>
  </div>
</template>
