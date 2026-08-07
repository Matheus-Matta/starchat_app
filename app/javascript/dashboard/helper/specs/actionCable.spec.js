import { describe, it, beforeEach, afterEach, expect, vi } from 'vitest';
import ActionCableConnector from '../actionCable';

const whatsappCallMocks = vi.hoisted(() => ({
  isLocal: vi.fn(() => false),
  dismissCall: vi.fn(),
  setCallActive: vi.fn(),
  calls: [{ callSid: 'provider-call-1' }],
}));

vi.mock('dashboard/stores/calls', () => ({
  useCallsStore: () => ({
    calls: whatsappCallMocks.calls,
    dismissCall: whatsappCallMocks.dismissCall,
    setCallActive: whatsappCallMocks.setCallActive,
  }),
}));

vi.mock('dashboard/composables/useWhatsappCallSession', () => ({
  applyOutboundAnswer: vi.fn(),
  armOutboundRecorder: vi.fn(),
  handleWhatsappRemoteEnd: vi.fn(),
  isLocalWhatsappCall: whatsappCallMocks.isLocal,
}));

vi.mock('shared/helpers/mitt', () => ({
  emitter: {
    emit: vi.fn(),
  },
}));

vi.mock('dashboard/composables/useImpersonation', () => ({
  useImpersonation: () => ({
    isImpersonating: { value: false },
  }),
}));

global.chatwootConfig = {
  websocketURL: 'wss://test.chatwoot.com',
};

describe('ActionCableConnector - Copilot Tests', () => {
  let store;
  let actionCable;
  let mockDispatch;

  beforeEach(() => {
    vi.clearAllMocks();
    whatsappCallMocks.isLocal.mockReturnValue(false);
    mockDispatch = vi.fn();
    store = {
      $store: {
        dispatch: mockDispatch,
        getters: {
          getCurrentAccountId: 1,
          'accounts/isFeatureEnabledonAccount': vi.fn(() => true),
        },
      },
    };

    actionCable = ActionCableConnector.init(store.$store, 'test-token');
  });

  afterEach(() => {
    vi.useRealTimers();
  });
  describe('copilot event handlers', () => {
    it('should register the copilot.message.created event handler', () => {
      expect(Object.keys(actionCable.events)).toContain(
        'copilot.message.created'
      );
      expect(actionCable.events['copilot.message.created']).toBe(
        actionCable.onCopilotMessageCreated
      );
    });

    it('should handle the copilot.message.created event through the ActionCable system', () => {
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
      expect(mockDispatch).toHaveBeenCalledWith(
        'copilotMessages/upsert',
        copilotData
      );
    });
  });

  describe('conversation unread count event handlers', () => {
    it('should register the conversation.unread_count_changed event handler', () => {
      expect(Object.keys(actionCable.events)).toContain(
        'conversation.unread_count_changed'
      );
      expect(actionCable.events['conversation.unread_count_changed']).toBe(
        actionCable.onConversationUnreadCountChanged
      );
    });

    it('should refetch unread counts when unread count changes', () => {
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledWith('conversationUnreadCounts/get');
    });

    it('does not refetch unread counts when unread count feature is disabled', () => {
      store.$store.getters[
        'accounts/isFeatureEnabledonAccount'
      ].mockReturnValue(false);

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).not.toHaveBeenCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('should throttle unread count refetches for repeated events', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(4999);
      expect(mockDispatch).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(1);
      expect(mockDispatch).toHaveBeenCalledTimes(2);
      expect(mockDispatch).toHaveBeenLastCalledWith(
        'conversationUnreadCounts/get'
      );
    });

    it('clears pending unread count refetch before immediate refetch', () => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date('2026-01-01T00:00:00Z'));

      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      vi.advanceTimersByTime(1000);
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      vi.setSystemTime(new Date('2026-01-01T00:00:06Z'));
      actionCable.onReceived({
        event: 'conversation.unread_count_changed',
        data: { account_id: 1 },
      });

      expect(mockDispatch).toHaveBeenCalledTimes(2);

      vi.advanceTimersByTime(4000);
      expect(mockDispatch).toHaveBeenCalledTimes(2);
    });
  });

  describe('WhatsApp call event handlers', () => {
    const callData = {
      id: 42,
      call_id: 'provider-call-1',
      provider: 'whatsapp',
      account_id: 1,
    };

    it('removes an accepted inbound call from tabs that do not own its WebRTC session', () => {
      actionCable.onReceived({ event: 'voice_call.accepted', data: callData });

      expect(whatsappCallMocks.dismissCall).toHaveBeenCalledWith(
        'provider-call-1'
      );
    });

    it('keeps an accepted inbound call in the tab that owns its WebRTC session', () => {
      whatsappCallMocks.isLocal.mockReturnValue(true);

      actionCable.onReceived({ event: 'voice_call.accepted', data: callData });

      expect(whatsappCallMocks.dismissCall).not.toHaveBeenCalled();
    });

    it('removes an accepted outbound call from tabs that do not own its WebRTC session', () => {
      actionCable.onReceived({
        event: 'voice_call.outbound_accepted',
        data: callData,
      });

      expect(whatsappCallMocks.dismissCall).toHaveBeenCalledWith(
        'provider-call-1'
      );
      expect(whatsappCallMocks.setCallActive).not.toHaveBeenCalled();
    });
  });
});
