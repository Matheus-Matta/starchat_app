// Window events the host page can listen to. dispatchWindowEvent also fires a
// starchats:* twin for each of these, so embeds written before the rename keep working.
export const STARCHATS_ERROR = 'starchats:error';
export const STARCHATS_ON_MESSAGE = 'starchats:on-message';
export const STARCHATS_ON_START_CONVERSATION =
  'starchats:on-start-conversation';
export const STARCHATS_POSTBACK = 'starchats:postback';
export const STARCHATS_READY = 'starchats:ready';
export const STARCHATS_OPENED = 'starchats:opened';
export const STARCHATS_CLOSED = 'starchats:closed';
