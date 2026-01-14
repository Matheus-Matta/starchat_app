<script setup>
defineProps({
  items: { type: Array, default: () => [] },
});
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      v-for="item in items"
      :key="item.id"
      class="flex flex-col bg-white dark:bg-n-solid-2 p-4 rounded-md shadow-sm border border-n-weak dark:border-n-weak/50"
    >
      <div class="flex justify-between items-start">
        <div class="flex flex-col">
          <h3 class="font-medium text-n-slate-12">{{ item.title }}</h3>
          <span class="text-sm text-n-slate-11">{{ item.organization_name }}
            <span v-if="item.person_name">- {{ item.person_name }}</span></span>
        </div>
        <span
          v-if="item.value"
          class="text-sm font-semibold text-n-slate-12 bg-n-alpha-2 px-2 py-1 rounded"
          >{{ item.value.amount }} {{ item.value.currency }}</span>
      </div>
      <div class="mt-2 text-xs text-n-slate-10 flex gap-2">
        <span v-if="item.label_ids">Labels: {{ item.label_ids }}</span>
      </div>
    </div>
    <div v-if="items.length === 0" class="text-center p-4 text-n-slate-11">
      No leads found.
    </div>
  </div>
</template>
