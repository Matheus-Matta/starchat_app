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
          <h3 class="font-medium text-n-slate-12 flex items-center gap-2">
            <span class="capitalize">{{ item.type }}</span>
            <span>-</span>
            <span>{{ item.subject }}</span>
          </h3>
          <span class="text-sm text-n-slate-11">
            {{ item.date }} {{ item.time }}
          </span>
        </div>
        <span
          class="text-xs font-semibold px-2 py-1 rounded"
          :class="
            item.done
              ? 'bg-green-100 text-green-700'
              : 'bg-yellow-100 text-yellow-700'
          "
        >
          {{ item.done ? 'Done' : 'To Do' }}
        </span>
      </div>
      <div
        v-if="item.deal_title || item.person_name"
        class="mt-2 text-xs text-n-slate-10"
      >
        Related to: {{ item.deal_title }}
        <span v-if="item.person_name">/ {{ item.person_name }}</span>
      </div>
    </div>
    <div v-if="items.length === 0" class="text-center p-4 text-n-slate-11">
      No activities found.
    </div>
  </div>
</template>
