export const createEvent = ({ eventName, data = null }) => {
  let event;
  if (typeof window.CustomEvent === 'function') {
    event = new CustomEvent(eventName, { detail: data });
  } else {
    event = document.createEvent('CustomEvent');
    event.initCustomEvent(eventName, false, false, data);
  }
  return event;
};

// Host pages listen for these by name, and that name is written in the customer's own
// HTML. Every starchats:* event therefore also goes out under its former chatwoot:*
// name so embeds installed before the rename keep receiving it. The two prefixes must
// stay different — collapsing them dispatches the same name twice and silently drops
// every pre-rename integration.
const LEGACY_EVENT_PREFIX = 'chatwoot:';
const EVENT_PREFIX = 'starchats:';

export const dispatchWindowEvent = ({ eventName, data }) => {
  window.dispatchEvent(createEvent({ eventName, data }));

  if (!eventName.startsWith(EVENT_PREFIX)) return;

  const legacyEventName = eventName.replace(EVENT_PREFIX, LEGACY_EVENT_PREFIX);
  window.dispatchEvent(createEvent({ eventName: legacyEventName, data }));
};
