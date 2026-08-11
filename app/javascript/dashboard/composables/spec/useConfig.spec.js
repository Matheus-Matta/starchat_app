import { useConfig } from '../useConfig';

describe('useConfig', () => {
  const originalStarchatsConfig = window.starchatsConfig;

  beforeEach(() => {
    window.starchatsConfig = {
      hostURL: 'https://example.com',
      vapidPublicKey: 'vapid-key',
      enabledLanguages: ['en', 'fr'],
    };
  });

  afterEach(() => {
    window.starchatsConfig = originalStarchatsConfig;
  });

  it('returns the correct configuration values', () => {
    const config = useConfig();

    expect(config.hostURL).toBe('https://example.com');
    expect(config.vapidPublicKey).toBe('vapid-key');
    expect(config.enabledLanguages).toEqual(['en', 'fr']);
  });

  it('handles missing configuration values', () => {
    window.starchatsConfig = {};
    const config = useConfig();

    expect(config.hostURL).toBeUndefined();
    expect(config.vapidPublicKey).toBeUndefined();
    expect(config.enabledLanguages).toBeUndefined();
  });

  it('handles undefined window.starchatsConfig', () => {
    window.starchatsConfig = undefined;
    const config = useConfig();

    expect(config.hostURL).toBeUndefined();
    expect(config.vapidPublicKey).toBeUndefined();
    expect(config.enabledLanguages).toBeUndefined();
  });
});
