import { dispatchWindowEvent } from '../CustomEventHelper';

describe('dispatchWindowEvent', () => {
  beforeEach(() => {
    window.dispatchEvent = vi.fn();
  });

  const dispatchedNames = () =>
    window.dispatchEvent.mock.calls.map(([event]) => event.type);

  it('dispatches the event', () => {
    dispatchWindowEvent({ eventName: 'starchats:ready' });

    expect(dispatchedNames()).toContain('starchats:ready');
  });

  // Embeds installed before the rename listen for starchats:* on their own pages, so
  // dropping the twin would silently break every one of them.
  it('also dispatches the legacy starchats event for backwards compatibility', () => {
    dispatchWindowEvent({ eventName: 'starchats:ready' });

    expect(dispatchedNames()).toEqual(['starchats:ready', 'starchats:ready']);
  });

  it('passes the same payload to both names', () => {
    const data = { message: 'hello' };
    dispatchWindowEvent({ eventName: 'starchats:on-message', data });

    const payloads = window.dispatchEvent.mock.calls.map(
      ([event]) => event.detail
    );
    expect(payloads).toEqual([data, data]);
  });

  it('does not invent a twin for events outside the starchats namespace', () => {
    dispatchWindowEvent({ eventName: 'some:other-event' });

    expect(dispatchedNames()).toEqual(['some:other-event']);
  });
});
