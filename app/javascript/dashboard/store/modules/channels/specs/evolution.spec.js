import evolution from '../evolution';
import EvolutionChannel from 'dashboard/api/channel/EvolutionChannel';

vi.mock('dashboard/api/channel/EvolutionChannel', () => ({
  default: {
    show: vi.fn(),
    connect: vi.fn(),
    restart: vi.fn(),
    disconnect: vi.fn(),
    getSettings: vi.fn(),
    updateSettings: vi.fn(),
    migrateToWhatsapp: vi.fn(),
  },
}));

describe('#evolution store module', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('#migrateToWhatsapp', () => {
    const whatsappChannel = {
      phone_number: '+1234567890',
      api_key: 'cloud_key',
      phone_number_id: '111',
      business_account_id: '222',
    };

    it('calls the API client with the given channel id and credentials', async () => {
      EvolutionChannel.migrateToWhatsapp.mockResolvedValue({
        data: { inbox: { id: 7 }, needs_reauthorization: false },
      });

      await evolution.actions.migrateToWhatsapp({}, { id: 7, whatsappChannel });

      expect(EvolutionChannel.migrateToWhatsapp).toHaveBeenCalledWith(
        7,
        whatsappChannel
      );
    });

    it('returns the response payload on success', async () => {
      const payload = { inbox: { id: 7 }, needs_reauthorization: false };
      EvolutionChannel.migrateToWhatsapp.mockResolvedValue({ data: payload });

      const result = await evolution.actions.migrateToWhatsapp(
        {},
        { id: 7, whatsappChannel }
      );

      expect(result).toEqual(payload);
    });

    it('surfaces needs_reauthorization when the migration needs attention', async () => {
      const payload = { inbox: { id: 7 }, needs_reauthorization: true };
      EvolutionChannel.migrateToWhatsapp.mockResolvedValue({ data: payload });

      const result = await evolution.actions.migrateToWhatsapp(
        {},
        { id: 7, whatsappChannel }
      );

      expect(result.needs_reauthorization).toBe(true);
    });

    it('propagates errors so the caller can handle failed credentials', async () => {
      const error = {
        response: { data: { message: 'Invalid Credentials' } },
      };
      EvolutionChannel.migrateToWhatsapp.mockRejectedValue(error);

      await expect(
        evolution.actions.migrateToWhatsapp({}, { id: 7, whatsappChannel })
      ).rejects.toEqual(error);
    });
  });
});
