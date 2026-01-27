import { mount } from '@vue/test-utils';
import { vi } from 'vitest';
import PipedriveFilter from '../PipedriveFilter.vue';
import PipedriveAPI from 'dashboard/api/pipedrive';

// Mock dependencies
vi.mock('dashboard/api/pipedrive');
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));
vi.mock('@vueuse/core', async importOriginal => {
  const actual = await importOriginal();
  return {
    ...actual,
    useDebounceFn: fn => fn, // Disable debounce for tests
  };
});

const globalMocks = {
  $t: msg => msg,
};

describe('PipedriveFilter', () => {
  // Setup PipedriveAPI mocks
  beforeEach(() => {
    PipedriveAPI.getUsers = vi.fn().mockResolvedValue({
      data: {
        payload: [
          { id: 1, name: 'John Doe' },
          { id: 2, name: 'Jane Smith' },
        ],
      },
    });
    PipedriveAPI.getPersons = vi.fn().mockResolvedValue({
      data: { payload: [{ id: 100, name: 'Alice Client' }] },
    });
    PipedriveAPI.getOrganizations = vi.fn().mockResolvedValue({
      data: { payload: [{ id: 500, name: 'Acme Corp' }] },
    });
  });

  const mountComponent = (props = {}) => {
    return mount(PipedriveFilter, {
      props: {
        resourceType: 'deals',
        ...props,
      },
      global: {
        mocks: globalMocks,
        stubs: {
          Button: { template: '<button><slot /></button>' },
          // Stub ConditionRow but allow emitting events to simulate user interaction
          ConditionRow: {
            name: 'ConditionRow',
            props: [
              'attributeKey',
              'filterOperator',
              'values',
              'filterTypes',
              'queryOperator',
            ],
            emits: [
              'update:attributeKey',
              'update:filterOperator',
              'update:values',
              'remove',
            ],
            template: `
              <div class="condition-row-stub">
                <select 
                  class="attr-select" 
                  :value="attributeKey" 
                  @change="$emit('update:attributeKey', $event.target.value)"
                >
                   <option v-for="type in filterTypes" :key="type.attributeKey" :value="type.attributeKey">
                     {{ type.label }}
                   </option>
                </select>
                <input 
                  class="value-input"
                  :value="JSON.stringify(values)" 
                  @input="$emit('update:values', JSON.parse($event.target.value))" 
                />
              </div>
            `,
          },
        },
      },
    });
  };

  it('renders with default filter (searchSelect status)', () => {
    const wrapper = mountComponent();
    expect(wrapper.find('.condition-row-stub').exists()).toBe(true);
    // Initially renders 1 row
    expect(wrapper.findAll('.condition-row-stub').length).toBe(1);
  });

  it('generates correct payload for Status filter', async () => {
    const wrapper = mountComponent({ resourceType: 'deals' });
    const row = wrapper.findComponent({ name: 'ConditionRow' });

    // Simulate user selecting "Open" status
    // Status is a searchSelect, so values expects { id, name } objet or primitives for PipedriveFilter logic
    // But our component logic converts object {id, name} to value/label in applyFilter.
    // Let's simulate selecting the object.
    const statusValue = { id: 'open', name: 'Em aberto' };
    row.vm.$emit('update:values', statusValue);

    // Apply
    await wrapper.findAll('button').at(2).trigger('click'); // 0: Add, 1: Clear, 2: Apply

    const updateEvent = wrapper.emitted('update:appliedFilters');
    expect(updateEvent).toBeTruthy();
    const payload = updateEvent[0][0];

    expect(payload).toHaveLength(1);
    expect(payload[0]).toMatchObject({
      attributeKey: 'status',
      filterOperator: 'equal_to',
      value: 'open', // The ID
      label: 'Em aberto', // The Name
    });
  });

  it('generates correct payload for Async User filter (Owner)', async () => {
    const wrapper = mountComponent();
    let row = wrapper.findComponent({ name: 'ConditionRow' });

    // Change attribute to owner_id
    row.vm.$emit('update:attributeKey', 'owner_id');
    await wrapper.vm.$nextTick();

    // Re-fetch component because :key changed
    row = wrapper.findComponent({ name: 'ConditionRow' });

    // Simulate async selection (the AsyncSelect would emit the full object)
    const userObj = { id: 1, name: 'John Doe', email: 'john@example.com' };
    row.vm.$emit('update:values', userObj);

    // Apply
    await wrapper.findAll('button').at(2).trigger('click'); // Apply

    const payload = wrapper.emitted('update:appliedFilters')[0][0];
    expect(payload[0]).toMatchObject({
      attributeKey: 'owner_id',
      value: 1, // ID
      label: 'John Doe',
      meta: userObj, // Full object preserved
    });
  });

  it('generates correct payload for Date filter', async () => {
    const wrapper = mountComponent();
    let row = wrapper.findComponent({ name: 'ConditionRow' });

    row.vm.$emit('update:attributeKey', 'add_time');
    await wrapper.vm.$nextTick();

    // Re-fetch component
    row = wrapper.findComponent({ name: 'ConditionRow' });

    // Set operator (logic depends on it)
    row.vm.$emit('update:filterOperator', 'is_greater_than');

    // Date picker emits a string or timestamp
    row.vm.$emit('update:values', '2023-01-01');

    await wrapper.findAll('button').at(2).trigger('click'); // Apply

    const payload = wrapper.emitted('update:appliedFilters')[0][0];
    expect(payload[0]).toMatchObject({
      attributeKey: 'created_from',
      value: '2023-01-01',
      label: '2023-01-01',
    });
  });

  it('handles multiple conditions', async () => {
    const wrapper = mountComponent();

    // Add second condition
    await wrapper.findAll('button').at(0).trigger('click'); // Add Condition
    expect(wrapper.findAll('.condition-row-stub').length).toBe(2);

    let rows = wrapper.findAllComponents({ name: 'ConditionRow' });

    // Row 1: Status = Won
    // Status is default, so key shouldn't change unless we change attribute. Status is default.
    // Changing value should be fine.
    rows.at(0).vm.$emit('update:values', { id: 'won', name: 'Won' });

    // Row 2: Person (Default is status, so changing to person changes key)
    rows.at(1).vm.$emit('update:attributeKey', 'person_id');
    await wrapper.vm.$nextTick();

    // Re-fetch rows
    rows = wrapper.findAllComponents({ name: 'ConditionRow' });

    rows.at(1).vm.$emit('update:values', { id: 100, name: 'Alice Client' });

    await wrapper.findAll('button').at(2).trigger('click'); // Apply

    const payload = wrapper.emitted('update:appliedFilters')[0][0];
    expect(payload).toHaveLength(2);
    expect(payload[0].value).toBe('won');
    expect(payload[1].value).toBe(100);
    expect(payload[1].label).toBe('Alice Client');
  });

  describe('Resource Types Specifics', () => {
    it('shows Activities specific filters (Type, Due Date)', async () => {
      const wrapper = mountComponent({ resourceType: 'activities' });
      // We interact with the filter types logical definition (via provider)
      // We can inspect the props passed to ConditionRow
      const row = wrapper.findComponent({ name: 'ConditionRow' });
      const types = row.props('filterTypes');

      const typeKeys = types.map(t => t.attributeKey);
      expect(typeKeys).toContain('type');
      expect(typeKeys).toContain('due_date');
      expect(typeKeys).toContain('status');
    });

    it('shows Leads specific status options', async () => {
      const wrapper = mountComponent({ resourceType: 'leads' });
      const row = wrapper.findComponent({ name: 'ConditionRow' });
      const types = row.props('filterTypes');

      const statusFilter = types.find(t => t.attributeKey === 'status');
      // Validating against keys defined in provider
      const optionIds = statusFilter.options.map(o => o.id);
      expect(optionIds).toContain('not_archived');
      expect(optionIds).toContain('archived');
      expect(optionIds).not.toContain('won'); // 'won' is for deals
    });
  });
});
