import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { createStore } from 'vuex';
import ContactsForm from './ContactsForm.vue';

describe('ContactsForm', () => {
  const ComboBoxStub = {
    name: 'ComboBox',
    props: [
      'modelValue',
      'options',
      'placeholder',
      'multiple',
      'disabledValues',
    ],
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

  const createWrapper = ({ contactData = {} } = {}) => {
    const store = createStore({
      getters: {
        'inboxes/getInboxes': () => [],
        'agents/getAgents': () => [
          { id: 1, name: 'Agent One' },
          { id: 2, name: 'Agent Two' },
        ],
      },
    });

    return mount(ContactsForm, {
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
  };

  it('renders a responsible agent select with a clear option', () => {
    const wrapper = createWrapper({
      contactData: {
        id: 1,
        name: 'Jane Doe',
      },
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 1)
    );

    expect(agentCombo).toBeTruthy();
    expect(
      agentCombo.props('options').some(option => option.value === null)
    ).toBe(true);
  });

  it('prefills responsible agent value when provided', () => {
    const wrapper = createWrapper({
      contactData: {
        id: 1,
        name: 'Jane Doe',
        responsibleAgentId: 2,
      },
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 2)
    );

    expect(agentCombo.props('modelValue')).toBe(2);
  });

  it('emits updates when responsible agent changes', async () => {
    const wrapper = createWrapper({
      contactData: {
        id: 1,
        name: 'Jane Doe',
      },
    });

    const comboBoxes = wrapper.findAllComponents(ComboBoxStub);
    const agentCombo = comboBoxes.find(combo =>
      combo.props('options').some(option => option.value === 2)
    );

    agentCombo.vm.$emit('update:modelValue', 2);
    await nextTick();

    const updates = wrapper.emitted('update');
    expect(updates).toBeTruthy();
    expect(updates[updates.length - 1][0].responsibleAgentId).toBe(2);
  });
});
