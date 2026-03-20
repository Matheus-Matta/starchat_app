import { describe, it, beforeEach, expect, vi } from 'vitest';
import ActionCableConnector from '../actionCable';

const mockEmitterEmit = vi.fn();

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: mockEmitterEmit,
  },
}));

vi.mock('dashboard/composables/useImpersonation', () => ({
  useImpersonation: () => ({
    isImpersonating: { value: false },
  }),
}));

global.chatwootConfig = {
  websocketURL: 'wss://test.starchats.com.br',
};

describe('ActionCableConnector - Copilot Tests', () => {
  let store;
  let actionCable;
  let mockDispatch;

  beforeEach(() => {
    vi.clearAllMocks();
    mockDispatch = vi.fn();
    store = {
      $store: {
        dispatch: mockDispatch,
        getters: {
          getCurrentAccountId: 1,
        },
      },
    };

    actionCable = ActionCableConnector.init(store.$store, 'test-token');
  });

  it('registers the copilot.message.created event handler', () => {
    expect(Object.keys(actionCable.events)).toContain('copilot.message.created');
    expect(actionCable.events['copilot.message.created']).toBe(
      actionCable.onCopilotMessageCreated
    );
  });

  it('handles the copilot.message.created event through the ActionCable system', () => {
    const copilotData = {
      id: 2,
      content: 'This is a copilot message from ActionCable',
      conversation_id: 456,
      created_at: '2025-05-27T15:58:04-06:00',
      account_id: 1,
    };
    actionCable.onReceived({
      event: 'copilot.message.created',
      data: copilotData,
    });
    expect(mockDispatch).toHaveBeenCalledWith('copilotMessages/upsert', copilotData);
  });

  it('emits monitoring refresh when message.created is received', () => {
    const messageData = {
      conversation: { last_activity_at: '2025-05-27T15:58:04-06:00' },
      conversation_id: 456,
      account_id: 1,
    };

    actionCable.onReceived({
      event: 'message.created',
      data: messageData,
    });

    expect(mockDispatch).toHaveBeenCalledWith('addMessage', messageData);
    expect(mockDispatch).toHaveBeenCalledWith('updateConversationLastActivity', {
      lastActivityAt: messageData.conversation.last_activity_at,
      conversationId: messageData.conversation_id,
    });
    expect(mockEmitterEmit).toHaveBeenCalledWith('monitoring:refresh_snapshot');
  });

  it('emits monitoring refresh when evolution.connection_update is received', () => {
    const evolutionData = {
      account_id: 1,
      inbox_id: 12,
      state: 'connected',
    };

    actionCable.onReceived({
      event: 'evolution.connection_update',
      data: evolutionData,
    });

    expect(mockEmitterEmit).toHaveBeenCalledWith('monitoring:refresh_snapshot');
  });
});
