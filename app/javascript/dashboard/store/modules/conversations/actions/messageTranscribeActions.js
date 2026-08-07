import MessageApi from '../../../../api/inbox/message';

export default {
  // Unlike translateMessage, errors are NOT swallowed here — this is a manual,
  // user-triggered fallback (context menu), so the caller shows success/error feedback.
  async transcribeAudioMessage(_, { conversationId, messageId }) {
    await MessageApi.transcribeAudio(conversationId, messageId);
  },
};
