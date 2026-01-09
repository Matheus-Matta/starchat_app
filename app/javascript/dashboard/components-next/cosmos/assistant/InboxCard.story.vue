<script setup>
import InboxCard from './InboxCard.vue';
import { inboxes } from 'dashboard/components-next/cosmos/pageComponents/emptyStates/cosmosEmptyStateContent.js';
</script>

<template>
  <Story
    title="Cosmos/Assistant/InboxCard"
    :layout="{ type: 'grid', width: '700px' }"
  >
    <Variant title="Inbox Card">
      <div
        v-for="inbox in inboxes"
        :key="inbox.id"
        class="px-20 py-4 bg-n-background"
      >
        <InboxCard :id="inbox.id" :inbox="inbox" />
      </div>
    </Variant>
  </Story>
</template>
