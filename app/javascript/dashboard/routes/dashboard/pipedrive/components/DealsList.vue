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
          <h3 class="font-medium text-n-slate-12">
            {{ item.title }}
          </h3>
          <span class="text-sm text-n-slate-11">
            {{ item.org_name }}
            <span v-if="item.person_name">- {{ item.person_name }}</span>
          </span>
        </div>
        <span
          class="text-sm font-semibold text-n-slate-12 bg-n-alpha-2 px-2 py-1 rounded"
        >
          {{ item.formatted_value }} {{ item.currency }}
        </span>
      </div>
      <div class="mt-2 text-xs text-n-slate-10 flex gap-2">
        <span>{{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.MODAL.TABLE.STATUS') }}:
          {{ item.status }}</span>
        <span>{{ $t('INTEGRATION_SETTINGS.PIPEDRIVE.MODAL.TABLE.STAGE') }}:
          {{ item.stage_id }}</span>
      </div>
    </div>
    <div v-if="items.length === 0" class="text-center p-4 text-n-slate-11">
      {{ $t('CONTACTS_LAYOUT.NO_RECORDS_FOUND') }}
    </div>
  </div>
</template>
