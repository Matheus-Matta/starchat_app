import { createConsumer } from '@rails/actioncable';

const PRESENCE_INTERVAL = 15000;
// Exponential backoff config for WebSocket reconnection
const RECONNECT_BASE_INTERVAL = 1000;
const RECONNECT_MAX_INTERVAL = 30000;

class BaseActionCableConnector {
  static isDisconnected = false;

  constructor(app, pubsubToken, websocketHost = '') {
    const websocketURL = websocketHost ? `${websocketHost}/cable` : undefined;

    this.consumer = createConsumer(websocketURL);
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: 'RoomChannel',
        pubsub_token: pubsubToken,
        account_id: app.$store.getters.getCurrentAccountId,
        user_id: app.$store.getters.getCurrentUserID,
      },
      {
        updatePresence() {
          this.perform('update_presence');
        },
        connected: () => {
          this.subscription.updatePresence();
        },
        received: this.onReceived,
        disconnected: () => {
          BaseActionCableConnector.isDisconnected = true;
          this.onDisconnected();
          this.initReconnectTimer();
        },
      }
    );
    this.app = app;
    this.events = {};
    this.reconnectTimer = null;
    this.reconnectAttempts = 0;
    this.isAValidEvent = () => true;
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this);
    this.handleFreeze = this.handleFreeze.bind(this);
    this.handleResume = this.handleResume.bind(this);
    document.addEventListener('visibilitychange', this.handleVisibilityChange);
    // Page Lifecycle API: fired when mobile browser freezes/unfreezes the tab
    document.addEventListener('freeze', this.handleFreeze);
    document.addEventListener('resume', this.handleResume);

    this.triggerPresenceInterval = () => {
      setTimeout(() => {
        try {
          this.subscription.updatePresence();
        } catch (error) {
          // ignore
        }
        this.triggerPresenceInterval();
      }, PRESENCE_INTERVAL);
    };
    this.triggerPresenceInterval();
  }

  checkConnection() {
    const isConnectionActive = this.consumer.connection.isOpen();
    const isReconnected =
      BaseActionCableConnector.isDisconnected && isConnectionActive;
    if (isReconnected) {
      this.clearReconnectTimer();
      this.reconnectAttempts = 0;
      this.onReconnect();
      BaseActionCableConnector.isDisconnected = false;
    } else {
      // Actively try to open the connection on each check
      if (!this.consumer.connection.isOpen()) {
        try {
          this.consumer.connection.open();
        } catch (_e) {
          // ignore
        }
      }
      this.initReconnectTimer();
    }
  }

  clearReconnectTimer = () => {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  };

  initReconnectTimer = () => {
    this.clearReconnectTimer();
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, capped at 30s
    const delay = Math.min(
      RECONNECT_BASE_INTERVAL * 2 ** this.reconnectAttempts,
      RECONNECT_MAX_INTERVAL
    );
    this.reconnectAttempts += 1;
    this.reconnectTimer = setTimeout(() => {
      this.checkConnection();
    }, delay);
  };

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {};

  // eslint-disable-next-line class-methods-use-this
  onDisconnected = () => {};

  handleVisibilityChange() {
    if (document.visibilityState === 'visible') {
      try {
        this.consumer.connection.open();
        this.subscription.updatePresence();
      } catch (error) {
        // ignore
      }
    }
  }

  // Fired by Page Lifecycle API when mobile browser freezes the tab (background)
  // eslint-disable-next-line class-methods-use-this
  handleFreeze() {
    // Nothing to do — presence will stay alive for PRESENCE_DURATION (300s)
  }

  // Fired by Page Lifecycle API when the frozen tab is resumed (foreground)
  handleResume() {
    try {
      // Re-open the WebSocket if it was closed during freeze
      this.consumer.connection.open();
      this.subscription.updatePresence();
    } catch (error) {
      // ignore
    }
  }

  disconnect() {
    this.consumer.disconnect();
    document.removeEventListener(
      'visibilitychange',
      this.handleVisibilityChange
    );
    document.removeEventListener('freeze', this.handleFreeze);
    document.removeEventListener('resume', this.handleResume);
  }

  onReceived = ({ event, data } = {}) => {
    if (this.isAValidEvent(data)) {
      if (this.events[event] && typeof this.events[event] === 'function') {
        this.events[event](data);
      }
    }
  };
}

export default BaseActionCableConnector;
