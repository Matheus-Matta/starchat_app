<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { getInboxIconByType } from 'dashboard/helper/inbox';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import LiveChatCampaignDetails from './LiveChatCampaignDetails.vue';
import SMSCampaignDetails from './SMSCampaignDetails.vue';

const props = defineProps({
  campaignId: {
    type: Number,
    default: null,
  },
  title: {
    type: String,
    default: '',
  },
  message: {
    type: String,
    default: '',
  },
  isLiveChatType: {
    type: Boolean,
    default: false,
  },
  isEnabled: {
    type: Boolean,
    default: false,
  },
  status: {
    type: String,
    default: '',
  },
  sender: {
    type: Object,
    default: null,
  },
  inbox: {
    type: Object,
    default: null,
  },
  scheduledAt: {
    type: Number,
    default: 0,
  },
  detailRouteName: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();
const router = useRouter();

const STATUS_COMPLETED = 'completed';
const STATUS_DRAFT = 'draft';

const { formatMessage } = useMessageFormatter();

const isDraft = computed(() => props.status === STATUS_DRAFT);

const isActive = computed(() => {
  if (props.isLiveChatType) return props.isEnabled;
  return props.status !== STATUS_COMPLETED && props.status !== STATUS_DRAFT;
});

const statusTextColor = computed(() => {
  if (isDraft.value) return 'text-n-yellow-11';
  return {
    'text-n-teal-11': isActive.value,
    'text-n-slate-12': !isActive.value,
  };
});

const statusBadgeClass = computed(() => {
  if (isDraft.value) return 'bg-n-yellow-3 text-n-yellow-11';
  return 'bg-n-alpha-2';
});

const campaignStatus = computed(() => {
  if (props.isLiveChatType) {
    return props.isEnabled
      ? t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.ENABLED')
      : t('CAMPAIGN.LIVE_CHAT.CARD.STATUS.DISABLED');
  }

  if (isDraft.value) return t('CAMPAIGN.CARD.STATUS.DRAFT');

  return props.status === STATUS_COMPLETED
    ? t('CAMPAIGN.SMS.CARD.STATUS.COMPLETED')
    : t('CAMPAIGN.SMS.CARD.STATUS.SCHEDULED');
});

const inboxName = computed(() => props.inbox?.name || '');

const inboxIcon = computed(() => {
  const { medium, channel_type: type } = props.inbox;
  return getInboxIconByType(type, medium);
});

const navigateToDetail = () => {
  if (!props.detailRouteName || !props.campaignId) return;
  router.push({ name: props.detailRouteName, params: { id: props.campaignId } });
};
</script>

<template>
  <CardLayout layout="row">
    <div class="flex flex-col items-start justify-between flex-1 min-w-0 gap-2">
      <div class="flex justify-between gap-3 w-fit">
        <span
          class="text-base font-medium capitalize text-n-slate-12 line-clamp-1"
        >
          {{ title }}
        </span>
        <span
          class="text-xs font-medium inline-flex items-center h-6 px-2 py-0.5 rounded-md"
          :class="[statusBadgeClass, statusTextColor]"
        >
          {{ campaignStatus }}
        </span>
      </div>
      <div
        v-dompurify-html="formatMessage(message, false, false, false)"
        class="text-sm text-n-slate-11 line-clamp-1 [&>p]:mb-0 h-6"
      />
      <div class="flex items-center w-full h-6 gap-2 overflow-hidden">
        <LiveChatCampaignDetails
          v-if="isLiveChatType"
          :sender="sender"
          :inbox-name="inboxName"
          :inbox-icon="inboxIcon"
        />
        <SMSCampaignDetails
          v-else
          :inbox-name="inboxName"
          :inbox-icon="inboxIcon"
          :scheduled-at="scheduledAt"
        />
      </div>
    </div>
    <div class="flex items-center justify-end gap-2">
      <Button
        v-if="!isLiveChatType && detailRouteName"
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-eye"
        :label="t('CAMPAIGN.CARD.DETAILS_BUTTON')"
        @click="navigateToDetail"
      />
      <Button
        v-if="isLiveChatType"
        variant="faded"
        size="sm"
        color="slate"
        icon="i-lucide-sliders-vertical"
        @click="emit('edit')"
      />
      <Button
        variant="faded"
        color="ruby"
        size="sm"
        icon="i-lucide-trash"
        @click="emit('delete')"
      />
    </div>
  </CardLayout>
</template>
