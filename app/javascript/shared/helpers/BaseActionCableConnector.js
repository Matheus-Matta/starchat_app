import { createConsumer } from '@rails/actioncable';

const PRESENCE_INTERVAL = 15000;
const RECONNECT_INTERVAL = 1000;

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
    this.isAValidEvent = () => true;
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this);
    document.addEventListener('visibilitychange', this.handleVisibilityChange);

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
      this.onReconnect();
      BaseActionCableConnector.isDisconnected = false;
    } else {
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
    this.reconnectTimer = setTimeout(() => {
      this.checkConnection();
    }, RECONNECT_INTERVAL);
  };

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {};

  // eslint-disable-next-line class-methods-use-this
  onDisconnected = () => {};

  handleVisibilityChange() {
    if (document.visibilityState === 'visible') {
      try {
        this.subscription.updatePresence();
      } catch (error) {
        // ignore
      }
    }
  }

  disconnect() {
    this.consumer.disconnect();
    document.removeEventListener(
      'visibilitychange',
      this.handleVisibilityChange
    );
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
