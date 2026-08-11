// Window events the host page can listen to. dispatchWindowEvent also fires a
// chatwoot:* twin for each of these, so embeds written before the rename keep working.
export const CHATWOOT_ERROR = 'starchats:error';
export const CHATWOOT_ON_MESSAGE = 'starchats:on-message';
export const CHATWOOT_ON_START_CONVERSATION = 'starchats:on-start-conversation';
export const CHATWOOT_POSTBACK = 'starchats:postback';
export const CHATWOOT_READY = 'starchats:ready';
export const CHATWOOT_OPENED = 'starchats:opened';
export const CHATWOOT_CLOSED = 'starchats:closed';
