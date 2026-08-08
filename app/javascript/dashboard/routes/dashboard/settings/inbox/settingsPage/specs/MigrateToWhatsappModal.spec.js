import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import MigrateToWhatsappModal from '../MigrateToWhatsappModal.vue';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
} from '../../channels/whatsapp/utils';

// Only the two functions that talk to Facebook are mocked; createMessageHandler
// and isValidBusinessData stay real so the postMessage handshake is exercised.
vi.mock('../../channels/whatsapp/utils', async importOriginal => ({
  ...(await importOriginal()),
  setupFacebookSdk: vi.fn(),
  initWhatsAppEmbeddedSignup: vi.fn(),
}));

// The real Dialog.vue combines a native <dialog> with @vueuse/components'
// OnClickOutside and a Teleport, none of which play well with jsdom/vitest's
// template compilation. We stub it with something that preserves its public
// contract (open/close methods, default slot, `confirm`/`close` emits) so we
// can exercise MigrateToWhatsappModal's own logic realistically.
const DialogStub = {
  name: 'Dialog',
  props: [
    'title',
    'description',
    'confirmButtonLabel',
    'isLoading',
    'type',
    'width',
  ],
  emits: ['confirm', 'close'],
  template: '<form @submit.prevent="$emit(\'confirm\')"><slot /></form>',
  methods: {
    open() {},
    close() {},
  },
};

const createWrapper = ({ migrateToWhatsapp } = {}) => {
  const migrateAction = migrateToWhatsapp || vi.fn().mockResolvedValue({});

  const store = createStore({
    modules: {
      evolution: {
        namespaced: true,
        actions: { migrateToWhatsapp: migrateAction },
      },
    },
  });

  const wrapper = mount(MigrateToWhatsappModal, {
    props: { channelId: 42 },
    global: {
      plugins: [store],
      stubs: { Dialog: DialogStub },
    },
  });

  return { wrapper, migrateAction };
};

const fillForm = async wrapper => {
  const inputs = wrapper.findAll('input');
  // Order matches the template: phoneNumber, phoneNumberId, businessAccountId, apiKey
  await inputs[0].setValue('+1234567890');
  await inputs[1].setValue('111');
  await inputs[2].setValue('222');
  await inputs[3].setValue('cloud_key');
};

describe('MigrateToWhatsappModal', () => {
  it('does not call the migrate action when required fields are missing', async () => {
    const { wrapper, migrateAction } = createWrapper();
    wrapper.vm.open();

    await wrapper.find('form').trigger('submit');

    expect(migrateAction).not.toHaveBeenCalled();
  });

  it('dispatches evolution/migrateToWhatsapp with the entered credentials', async () => {
    const migrateAction = vi
      .fn()
      .mockResolvedValue({ needs_reauthorization: false });
    const { wrapper } = createWrapper({ migrateToWhatsapp: migrateAction });
    wrapper.vm.open();

    await fillForm(wrapper);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(migrateAction).toHaveBeenCalledTimes(1);
    const [, payload] = migrateAction.mock.calls[0];
    expect(payload).toEqual({
      id: 42,
      whatsappChannel: {
        phone_number: '+1234567890',
        api_key: 'cloud_key',
        phone_number_id: '111',
        business_account_id: '222',
      },
    });
  });

  it('emits migrated with the response on success', async () => {
    const response = { needs_reauthorization: false, inbox: { id: 7 } };
    const migrateAction = vi.fn().mockResolvedValue(response);
    const { wrapper } = createWrapper({ migrateToWhatsapp: migrateAction });
    wrapper.vm.open();

    await fillForm(wrapper);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(wrapper.emitted('migrated')).toBeTruthy();
    expect(wrapper.emitted('migrated')[0]).toEqual([response]);
  });

  it('does not emit migrated when the API call fails', async () => {
    const migrateAction = vi.fn().mockRejectedValue({
      response: { data: { message: 'Invalid Credentials' } },
    });
    const { wrapper } = createWrapper({ migrateToWhatsapp: migrateAction });
    wrapper.vm.open();

    await fillForm(wrapper);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(wrapper.emitted('migrated')).toBeFalsy();
  });

  describe('when embedded signup is configured', () => {
    const emitFinishEvent = async (data = {}) => {
      window.dispatchEvent(
        new MessageEvent('message', {
          origin: 'https://www.facebook.com',
          data: JSON.stringify({
            type: 'WA_EMBEDDED_SIGNUP',
            event: 'FINISH',
            data: {
              business_id: 'business-1',
              waba_id: '222',
              phone_number_id: '111',
              ...data,
            },
          }),
        })
      );
      await flushPromises();
    };

    beforeEach(() => {
      window.chatwootConfig = {
        whatsappAppId: 'app-id',
        whatsappConfigurationId: 'config-id',
      };
      // vite.config.ts sets mockReset, so the implementations have to be
      // re-declared for every test rather than in the vi.mock factory.
      setupFacebookSdk.mockResolvedValue(undefined);
      initWhatsAppEmbeddedSignup.mockResolvedValue('auth-code-123');
    });

    afterEach(() => {
      delete window.chatwootConfig;
    });

    it('offers the Facebook login instead of the credentials form', () => {
      const { wrapper } = createWrapper();
      wrapper.vm.open();

      expect(wrapper.findAll('input')).toHaveLength(0);
      expect(wrapper.find('button[type="button"]').exists()).toBe(true);
    });

    it('migrates with the authorization code once the business data arrives', async () => {
      const migrateAction = vi
        .fn()
        .mockResolvedValue({ needs_reauthorization: false });
      const { wrapper } = createWrapper({ migrateToWhatsapp: migrateAction });
      wrapper.vm.open();

      // The Facebook button is the NextButton; the plain type="button" below it
      // is the "enter credentials manually" fallback link.
      await wrapper.findAll('button')[0].trigger('click');
      await flushPromises();

      expect(setupFacebookSdk).toHaveBeenCalledWith('app-id', undefined);
      expect(initWhatsAppEmbeddedSignup).toHaveBeenCalledWith('config-id');

      await emitFinishEvent();

      expect(migrateAction).toHaveBeenCalledTimes(1);
      const [, payload] = migrateAction.mock.calls[0];
      expect(payload).toEqual({
        id: 42,
        whatsappChannel: {
          code: 'auth-code-123',
          business_id: 'business-1',
          waba_id: '222',
          phone_number_id: '111',
        },
      });
      expect(wrapper.emitted('migrated')).toBeTruthy();
    });

    it('ignores signup events while the dialog is closed', async () => {
      const migrateAction = vi.fn().mockResolvedValue({});
      createWrapper({ migrateToWhatsapp: migrateAction });

      await emitFinishEvent();

      expect(migrateAction).not.toHaveBeenCalled();
    });

    it('falls back to the credentials form when the user opts out', async () => {
      const { wrapper } = createWrapper();
      wrapper.vm.open();

      await wrapper.find('button[type="button"]').trigger('click');

      expect(wrapper.findAll('input')).toHaveLength(4);
    });
  });
});
