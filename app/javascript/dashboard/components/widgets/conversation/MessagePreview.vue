<script>
import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { ATTACHMENT_ICONS } from 'shared/constants/messages';

export default {
  name: 'MessagePreview',
  props: {
    message: {
      type: Object,
      required: true,
    },
    showMessageType: {
      type: Boolean,
      default: true,
    },
    defaultEmptyMessage: {
      type: String,
      default: '',
    },
  },
  setup() {
    const { getPlainText } = useMessageFormatter();
    return {
      getPlainText,
    };
  },
  computed: {
    messageByAgent() {
      const messageType = this.message?.message_type;
      return messageType === MESSAGE_TYPE.OUTGOING;
    },
    isMessageAnActivity() {
      const messageType = this.message?.message_type;
      return messageType === MESSAGE_TYPE.ACTIVITY;
    },
    isMessagePrivate() {
      return !!this.message?.private;
    },
    parsedLastMessage() {
      const contentAttributes = this.message?.content_attributes;
      const { email: { subject } = {} } = contentAttributes || {};
      return this.getPlainText(subject || this.message?.content || '');
    },
    lastMessageFileType() {
      const attachments = this.message?.attachments || [];
      if (attachments.length > 0) {
        return attachments[0].file_type || attachments[0].fileType;
      }
      return null;
    },
    attachmentIcon() {
      return ATTACHMENT_ICONS[this.lastMessageFileType] || null;
    },
    attachmentMessageContent() {
      if (!this.lastMessageFileType) return 'CHAT_LIST.NO_CONTENT';
      return `CHAT_LIST.ATTACHMENTS.${this.lastMessageFileType}.CONTENT`;
    },
    isMessageSticker() {
      return this.message?.content_type === 'sticker';
    },
  },
};
</script>

<template>
  <div class="overflow-hidden text-ellipsis whitespace-nowrap">
    <template v-if="showMessageType">
      <fluent-icon
        v-if="isMessagePrivate"
        size="16"
        class="-mt-0.5 align-middle text-n-slate-11 inline-block"
        icon="lock-closed"
      />
      <fluent-icon
        v-else-if="messageByAgent"
        size="16"
        class="-mt-0.5 align-middle text-n-slate-11 inline-block"
        icon="arrow-reply"
      />
      <fluent-icon
        v-else-if="isMessageAnActivity"
        size="16"
        class="-mt-0.5 align-middle text-n-slate-11 inline-block"
        icon="info"
      />
    </template>

    <!-- Sticker Message -->
    <span v-if="isMessageSticker">
      <fluent-icon
        size="16"
        class="-mt-0.5 align-middle inline-block text-n-slate-11"
        icon="image"
      />
      {{ $t('CHAT_LIST.ATTACHMENTS.sticker.CONTENT') }}
    </span>

    <!-- Text Content -->
    <span v-else-if="message.content">
      {{ parsedLastMessage }}
    </span>

    <!-- Attachments -->
    <span v-else-if="message.attachments && message.attachments.length > 0">
      <fluent-icon
        v-if="attachmentIcon && showMessageType"
        size="16"
        class="-mt-0.5 align-middle inline-block text-n-slate-11"
        :icon="attachmentIcon"
      />
      {{ $t(attachmentMessageContent) }}
    </span>

    <!-- Empty/Fallback -->
    <span v-else>
      {{ defaultEmptyMessage || $t('CHAT_LIST.NO_CONTENT') }}
    </span>
  </div>
</template>
