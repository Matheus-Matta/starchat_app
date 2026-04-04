import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { createStore } from 'vuex';
import ContactsForm from './ContactsForm.vue';

describe('ContactsForm', () => {
  const ComboBoxStub = {
    name: 'ComboBox',
    props: {
      modelValue: { default: null },
      options: { type: Array, default: () => [] },
      placeholder: { type: String, default: '' },
      multiple: { type: Boolean, default: false },
      disabledValues: { type: Array, default: () => [] },
    },
    template: '<div class="combo-box-stub" />',
  };

  const InputStub = {
    name: 'Input',
    props: ['modelValue', 'placeholder', 'messageType'],
    template: '<input class="input-stub" />',
  };

  const PhoneInputStub = {
    name: 'PhoneNumberInput',
    props: ['modelValue', 'placeholder'],
    template: '<input class="phone-stub" />',
  };

  const createWrapper = ({ contactData = {}, agentsList = [] } = {}) => {
    const agentsGetAction = vi.fn();
    const store = createStore({
      modules: {
        agents: {
          namespaced: true,
          state: { records: agentsList },
          getters: {
            getAgents: state => state.records,
          },
          actions: {
            get: agentsGetAction,
          },
        },
        inboxes: {
          namespaced: true,
          state: { records: [] },
          getters: {
            getInboxes: () => [],
          },
        },
      },
    });

    const wrapper = mount(ContactsForm, {
      props: {
        contactData,
        isDetailsView: true,
      },
      global: {
        plugins: [store],
        stubs: {
          ComboBox: ComboBoxStub,
          Input: InputStub,
          PhoneNumberInput: PhoneInputStub,
          Icon: true,
        },
      },
    });

    return { wrapper, agentsGetAction };
  };

  it('dispatches agents/get on mount to populate the responsible agent list', async () => {
    const { agentsGetAction } = createWrapper();
    await nextTick();
    expect(agentsGetAction).toHaveBeenCalledTimes(1);
  });

  it('renders a responsible agent select without a clear option', () => {
    const { wrapper } = createWrapper({
      contactData: { id: 1, name: 'Jane Doe' },
      agentsList: [
        { id: 1, name: 'Agent One' },
        { id: 2, name: 'Agent Two' },
      ],
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 1)
    );

    expect(agentCombo).toBeTruthy();
    expect(
      agentCombo.props('options').some(option => option.value === null)
    ).toBe(false);
    expect(agentCombo.props('multiple')).toBe(true);
  });

  it('shows an empty list when agents store is empty (pre-fetch)', () => {
    const { wrapper } = createWrapper({
      contactData: { id: 1, name: 'Jane Doe' },
      agentsList: [],
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    // No combo with agent options should exist
    const agentCombo = comboBoxes.find(combo =>
      Array.isArray(combo.props('options')) &&
      combo.props('options').length === 0
    );

    expect(agentCombo).toBeTruthy();
  });

  it('prefills responsible agent ids when provided as array', () => {
    const { wrapper } = createWrapper({
      contactData: {
        id: 1,
        name: 'Jane Doe',
        responsibleAgentIds: [2],
      },
      agentsList: [
        { id: 1, name: 'Agent One' },
        { id: 2, name: 'Agent Two' },
      ],
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 2)
    );

    expect(agentCombo.props('modelValue')).toEqual([2]);
  });

  it('emits updates with array when responsible agents change', async () => {
    const { wrapper } = createWrapper({
      contactData: { id: 1, name: 'Jane Doe' },
      agentsList: [
        { id: 1, name: 'Agent One' },
        { id: 2, name: 'Agent Two' },
      ],
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 2)
    );

    agentCombo.vm.$emit('update:modelValue', [2]);
    await nextTick();

    const updates = wrapper.emitted('update');
    expect(updates).toBeTruthy();
    expect(updates[updates.length - 1][0].responsibleAgentIds).toEqual([2]);
  });

  it('supports selecting multiple agents at once', async () => {
    const { wrapper } = createWrapper({
      contactData: { id: 1, name: 'Jane Doe' },
      agentsList: [
        { id: 1, name: 'Agent One' },
        { id: 2, name: 'Agent Two' },
      ],
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 1)
    );

    agentCombo.vm.$emit('update:modelValue', [1, 2]);
    await nextTick();

    const updates = wrapper.emitted('update');
    expect(updates[updates.length - 1][0].responsibleAgentIds).toEqual([1, 2]);
  });
});
