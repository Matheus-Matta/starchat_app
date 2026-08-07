import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import MigrateToWhatsappModal from '../MigrateToWhatsappModal.vue';

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
});
