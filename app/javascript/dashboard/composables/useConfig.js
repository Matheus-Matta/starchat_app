/**
 * A function that provides access to various configuration values.
 * @returns {Object} An object containing configuration values.
 */
export function useConfig() {
  const config = window.starchatsConfig || {};

  /**
   * The host URL of the Starchats instance.
   * @type {string|undefined}
   */
  const hostURL = config.hostURL;

  /**
   * The VAPID public key for web push notifications.
   * @type {string|undefined}
   */
  const vapidPublicKey = config.vapidPublicKey;

  /**
   * An array of enabled languages in the Starchats instance.
   * @type {string[]|undefined}
   */
  const enabledLanguages = config.enabledLanguages;

  /**
   * Indicates whether the current instance is a starchat version.
   * @type {boolean}
   */

  /**
   * The name of the starchat plan, if applicable.
   * Returns "community" or "starchat"
   * @type {string|undefined}
   */
  const enterprisePlanName = config.enterprisePlanName;

  /**
   * Indicates whether inbox webhook events (ENABLE_INBOX_EVENTS) are enabled.
   * @type {boolean}
   */
  const inboxEventsEnabled = config.inboxEventsEnabled === 'true';

  return {
    hostURL,
    vapidPublicKey,
    enabledLanguages,
    enterprisePlanName,
    inboxEventsEnabled,
  };
}
