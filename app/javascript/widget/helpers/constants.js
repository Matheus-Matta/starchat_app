export const APP_BASE_URL = '';

export const MESSAGE_STATUS = {
  FAILED: 'failed',
  SUCCESS: 'success',
  PROGRESS: 'progress',
};

export const MESSAGE_TYPE = {
  INCOMING: 0,
  OUTGOING: 1,
  ACTIVITY: 2,
  TEMPLATE: 3,
};

export const WOOT_PREFIX = 'starchats-widget:';
// An sdk.js cached on a customer page from before the rename still posts under the old
// prefix, so messages are accepted under either name until those caches expire.
export const LEGACY_WOOT_PREFIX = 'chatwoot-widget:';
