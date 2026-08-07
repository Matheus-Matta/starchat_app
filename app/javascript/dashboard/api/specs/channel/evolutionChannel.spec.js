import ApiClient from '../../ApiClient';
import evolutionChannel from '../../channel/EvolutionChannel';

describe('#EvolutionChannel', () => {
  it('creates correct instance', () => {
    expect(evolutionChannel).toBeInstanceOf(ApiClient);
    expect(evolutionChannel).toHaveProperty('get');
    expect(evolutionChannel).toHaveProperty('show');
    expect(evolutionChannel).toHaveProperty('create');
    expect(evolutionChannel).toHaveProperty('connect');
    expect(evolutionChannel).toHaveProperty('restart');
    expect(evolutionChannel).toHaveProperty('disconnect');
    expect(evolutionChannel).toHaveProperty('getSettings');
    expect(evolutionChannel).toHaveProperty('updateSettings');
    expect(evolutionChannel).toHaveProperty('migrateToWhatsapp');
  });

  describe('#migrateToWhatsapp', () => {
    const originalAxios = window.axios;
    const originalPathname = window.location.pathname;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
      window.history.pushState({}, '', '/app/accounts/1/settings');
    });

    afterEach(() => {
      window.axios = originalAxios;
      window.history.pushState({}, '', originalPathname);
      vi.clearAllMocks();
    });

    it('posts the whatsapp credentials to the migrate_to_whatsapp endpoint', () => {
      const whatsappChannel = {
        phone_number: '+1234567890',
        api_key: 'cloud_key',
        phone_number_id: '111',
        business_account_id: '222',
      };

      evolutionChannel.migrateToWhatsapp(42, whatsappChannel);

      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/accounts/1/channels/evolution_channel/42/migrate_to_whatsapp',
        { whatsapp_channel: whatsappChannel }
      );
    });
  });
});
