<script setup>
import { computed, ref, watch } from 'vue';
import CampaignCard from 'dashboard/components-next/Campaigns/CampaignCard/CampaignCard.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const props = defineProps({
  campaigns: {
    type: Array,
    required: true,
  },
  isLiveChatType: {
    type: Boolean,
    default: false,
  },
  detailRouteName: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['edit', 'delete']);

const PAGE_SIZE = 25;

const currentPage = ref(1);

// Resets to the first page whenever the underlying list changes (e.g. after a
// filter change or a delete), so the view never gets stuck on an empty page.
watch(
  () => props.campaigns,
  () => {
    currentPage.value = 1;
  }
);

const paginatedCampaigns = computed(() => {
  const start = (currentPage.value - 1) * PAGE_SIZE;
  return props.campaigns.slice(start, start + PAGE_SIZE);
});

const handlePageChange = page => {
  currentPage.value = page;
};

const handleEdit = campaign => emit('edit', campaign);
const handleDelete = campaign => emit('delete', campaign);
</script>

<template>
  <div class="flex flex-col gap-4">
    <CampaignCard
      v-for="campaign in paginatedCampaigns"
      :key="campaign.id"
      :campaign-id="campaign.id"
      :title="campaign.title"
      :message="campaign.message"
      :is-enabled="campaign.enabled"
      :status="campaign.campaign_status"
      :sender="campaign.sender"
      :inbox="campaign.inbox"
      :scheduled-at="campaign.scheduled_at"
      :is-live-chat-type="isLiveChatType"
      :detail-route-name="detailRouteName"
      @edit="handleEdit(campaign)"
      @delete="handleDelete(campaign)"
    />
    <TableFooter
      :current-page="currentPage"
      :page-size="PAGE_SIZE"
      :total-count="campaigns.length"
      @page-change="handlePageChange"
    />
  </div>
</template>
