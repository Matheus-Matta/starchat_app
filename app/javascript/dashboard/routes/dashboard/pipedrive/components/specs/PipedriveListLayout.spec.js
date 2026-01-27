import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { vi } from 'vitest';
import PipedriveListLayout from '../PipedriveListLayout.vue';

// Mock useRouter
const mockPush = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush,
    currentRoute: { value: { params: { accountId: 1 } } },
  }),
}));

// Mock useI18n to avoid real i18n implementation issues
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

// Global mocks
const globalMocks = {
  $t: msg => msg,
};

describe('PipedriveListLayout', () => {
  let store;
  let actions;

  beforeEach(() => {
    actions = {
      'customViews/update': vi.fn(),
      'customViews/create': vi.fn(),
      'customViews/delete': vi.fn(),
    };
    store = createStore({
      actions,
    });
  });

  const mountComponent = (props = {}) => {
    return mount(PipedriveListLayout, {
      props: {
        headerTitle: 'Test Title',
        resourceType: 'deals',
        ...props,
      },
      global: {
        plugins: [store],
        mocks: globalMocks,
        stubs: {
          PipedriveFilter: {
            name: 'PipedriveFilter',
            template: '<div class="pipedrive-filter-stub"></div>',
            methods: { reset: vi.fn(), setFilters: vi.fn() },
            emits: ['update:applied-filters', 'close', 'update:modelValue'],
          },
          PipedriveSortMenu: true,
          ActiveFilterPreview: true,
          CreateSegmentDialog: {
            template: '<div></div>',
            methods: { open: vi.fn() },
          },
          DeleteSegmentDialog: {
            template: '<div></div>',
            methods: { dialogRef: { open: vi.fn(), close: vi.fn() } },
          },
          PaginationFooter: true,
          Button: true,
          Input: {
            template:
              '<input class="input-stub" :value="modelValue" @input="$emit(\'input\', $event)" />',
            props: ['modelValue'],
          },
          Icon: true,
        },
      },
    });
  };

  it('renders correctly', () => {
    const wrapper = mountComponent();
    expect(wrapper.text()).toContain('Test Title');
  });

  describe('Debounced Search', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });
    afterEach(() => {
      vi.useRealTimers();
    });

    it('emits search event when input changes (debounced)', () => {
      const wrapper = mountComponent();
      wrapper.vm.onSearchInput('search query');
      vi.runAllTimers();
      expect(wrapper.emitted('search')).toBeTruthy();
      expect(wrapper.emitted('search')[0]).toEqual(['search query']);
    });
  });

  describe('Filter functionality', () => {
    it('opens filter modal when button is clicked', async () => {
      const wrapper = mountComponent();
      await wrapper.find('#pipedrive-filter-button').trigger('click');
      expect(wrapper.vm.showFilterModal).toBe(true);
      await wrapper.vm.$nextTick();
      expect(wrapper.find('.pipedrive-filter-stub').exists()).toBe(true);
    });

    it('updates active filters and emits filter event when filters are applied', async () => {
      const wrapper = mountComponent();
      wrapper.vm.showFilterModal = true;
      await wrapper.vm.$nextTick();

      const filterComponent = wrapper.findComponent({
        name: 'PipedriveFilter',
      });
      expect(filterComponent.exists()).toBe(true);

      const sampleFilters = [
        {
          attributeKey: 'status',
          filterOperator: 'equal_to',
          value: 'open',
          label: 'Open',
        },
      ];

      filterComponent.vm.$emit('update:applied-filters', sampleFilters);

      expect(wrapper.vm.activeFilters).toEqual(sampleFilters);
      expect(wrapper.emitted('filter')).toBeTruthy();
      expect(wrapper.emitted('filter')[0]).toEqual([sampleFilters]);
    });

    it('shows ActiveFilterPreview when filters are present', async () => {
      const wrapper = mountComponent();
      wrapper.vm.activeFilters = [
        { attributeKey: 'status', label: 'Status', value: 'Open' },
      ];
      await wrapper.vm.$nextTick();
      expect(
        wrapper.findComponent({ name: 'ActiveFilterPreview' }).exists()
      ).toBe(true);
    });

    it('correctly handles leads active filters', async () => {
      const wrapper = mountComponent({ resourceType: 'leads' });
      const leadsFilters = [
        { attributeKey: 'status', value: 'archived', label: 'Archived' },
      ];
      wrapper.vm.activeFilters = leadsFilters;
      await wrapper.vm.$nextTick();
      const preview = wrapper.findComponent({ name: 'ActiveFilterPreview' });
      expect(preview.exists()).toBe(true);
      expect(preview.props('appliedFilters')).toEqual(leadsFilters);
    });
  });

  describe('Resource Types Pagination', () => {
    it('renders correct pagination key for deals', () => {
      const wrapper = mountComponent({ resourceType: 'deals' });
      const footer = wrapper.findComponent({ name: 'PaginationFooter' });
      expect(footer.props('currentPageInfo')).toBe(
        'INTEGRATION_SETTINGS.PIPEDRIVE.PAGINATION.SHOWING_DEALS'
      );
    });

    it('renders correct pagination key for leads', () => {
      const wrapper = mountComponent({ resourceType: 'leads' });
      const footer = wrapper.findComponent({ name: 'PaginationFooter' });
      expect(footer.props('currentPageInfo')).toBe(
        'INTEGRATION_SETTINGS.PIPEDRIVE.PAGINATION.SHOWING_LEADS'
      );
    });

    it('renders correct pagination key for activities', () => {
      const wrapper = mountComponent({ resourceType: 'activities' });
      const footer = wrapper.findComponent({ name: 'PaginationFooter' });
      expect(footer.props('currentPageInfo')).toBe(
        'INTEGRATION_SETTINGS.PIPEDRIVE.PAGINATION.SHOWING_ACTIVITIES'
      );
    });
  });
});
