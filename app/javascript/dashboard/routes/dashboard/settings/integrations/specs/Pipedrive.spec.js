import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { vi } from 'vitest';
import Pipedrive from '../Pipedrive.vue';

// Mock dependencies
vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

// Components stubs
const ModalStub = {
  template: '<div class="modal-stub" v-if="show"><slot /></div>',
  props: ['show', 'title'],
  emits: ['close'],
};

const IntegrationStub = {
  template: '<div class="integration-stub"><slot name="action" /><slot /></div>',
  props: [
    'integrationId',
    'integrationLogo',
    'integrationName',
    'integrationDescription',
    'integrationEnabled',
    'integrationAction',
    'actionButtonText',
    'deleteConfirmationText',
  ],
};

const ButtonStub = {
  template: '<button @click="$emit(\'click\')">{{ label }}</button>',
  props: ['label', 'isLoading', 'disabled'],
};

const InputStub = {
  template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  props: ['modelValue', 'placeholder'],
  emits: ['update:modelValue'],
};

const SwitchStub = {
  template: '<div class="switch-stub" @click="$emit(\'update:modelValue\', !modelValue)"></div>',
  props: ['modelValue', 'disabled'],
  emits: ['update:modelValue'],
};

const globalMocks = {
  $t: (key) => key,
};

describe('Pipedrive Integration Component', () => {
  let store;
  let actions;
  let getters;

  beforeEach(() => {
    actions = {
      'integrations/get': vi.fn(),
      'integrations/createHook': vi.fn(),
    };
    
    getters = {
      'integrations/getIntegration': () => (id) => ({
        id: 'pipedrive',
        name: 'Pipedrive',
        description: 'Pipedrive Integration',
        logo: 'pipedrive.png',
        enabled: false,
        settings: {},
      }),
      'integrations/getUIFlags': () => ({
        isCreatingPipedrive: false,
      }),
    };

    store = createStore({
      actions,
      getters,
    });
  });

  const mountComponent = () => {
    return mount(Pipedrive, {
      global: {
        plugins: [store],
        mocks: globalMocks,
        stubs: {
          Integration: IntegrationStub,
          Modal: ModalStub,
          Button: ButtonStub,
          Input: InputStub,
          Switch: SwitchStub,
        },
      },
    });
  };

  it('renders integration component correctly', async () => {
    const wrapper = mountComponent();
    // Wait for onMounted
    await wrapper.vm.$nextTick();
    expect(actions['integrations/get']).toHaveBeenCalledWith(expect.anything(), 'pipedrive');
    expect(wrapper.findComponent(IntegrationStub).exists()).toBe(true);
  });

  it('opens connect modal when connect button is clicked', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.$nextTick();
    
    // Find connect button inside Integration slot
    const connectBtn = wrapper.findAllComponents(ButtonStub).filter(b => b.props('label') === 'INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')[0];
    await connectBtn.trigger('click');
    
    expect(wrapper.vm.showConnectModal).toBe(true);
    expect(wrapper.find('.modal-stub').exists()).toBe(true);
  });

  it('submits connection form with correct payload', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.$nextTick();
    wrapper.vm.showConnectModal = true;
    await wrapper.vm.$nextTick();

    // Fill Inputs
    const inputs = wrapper.findAllComponents(InputStub);
    // API Token
    await inputs[0].vm.$emit('update:modelValue', 'test_token');
    // Company Domain
    await inputs[1].vm.$emit('update:modelValue', 'test_domain');

    // Submit
    const connectSubmitBtn = wrapper.findAllComponents(ButtonStub).filter(b => b.props('label') === 'INTEGRATION_SETTINGS.PIPEDRIVE.CONNECT_MODAL.CONNECT')[0];
    
    // Check if disabled prop respects validation (token && domain required)
    // Here we manually check logic or trigger click
    await connectSubmitBtn.trigger('click');

    expect(actions['integrations/createHook']).toHaveBeenCalledWith(expect.anything(), {
      app_id: 'pipedrive',
      settings: expect.objectContaining({
        api_token: 'test_token',
        company_domain: 'test_domain',
      }),
    });
  });

  it('populates settings when already enabled', async () => {
     getters['integrations/getIntegration'] = () => (id) => ({
        id: 'pipedrive',
        name: 'Pipedrive',
        enabled: true,
        settings: {
          api_token: 'existing_token',
          company_domain: 'existing_domain',
          sync_contacts: true
        },
      });
      
     store = createStore({ actions, getters });
     const wrapper = mountComponent();
     await wrapper.vm.$nextTick();
     
     expect(wrapper.vm.apiToken).toBe('existing_token');
     expect(wrapper.vm.companyDomain).toBe('existing_domain');
     expect(wrapper.vm.syncContacts).toBe(true);
  });
});
