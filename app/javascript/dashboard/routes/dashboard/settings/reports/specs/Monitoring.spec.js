import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { ref } from 'vue';

import Monitoring from '../Monitoring.vue';

const mockEmitterCallbacks = new Map();
const mockFetchSnapshot = vi.fn();

vi.mock('dashboard/composables/emitter', () => ({
  useEmitter: (eventName, callback) => {
    mockEmitterCallbacks.set(eventName, callback);
  },
}));

vi.mock('@vueuse/core', () => ({
  useDebounceFn: fn => fn,
  useFullscreen: () => ({
    isFullscreen: ref(false),
    toggle: vi.fn(),
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/components-next/spinner/Spinner.vue', () => ({
  default: { template: '<div />' },
}));

const store = createStore({
  modules: {
    monitoringReports: {
      namespaced: true,
      getters: {
        getSummary: () => ({
          total_inboxes: 0,
          online_inboxes: 0,
          warning_inboxes: 0,
          offline_inboxes: 0,
          total_agents: 0,
          agents_available: 0,
          agents_busy: 0,
          agents_offline: 0,
          total_active_conversations: 0,
        }),
        getInboxes: () => [],
        getAgents: () => [],
        getMonitoringUIFlags: () => ({
          isFetching: false,
          error: null,
          lastSyncedAt: null,
        }),
      },
      actions: {
        fetchSnapshot: mockFetchSnapshot,
      },
    },
    // The team filter reads teams/getTeams and dispatches teams/get on mount.
    teams: {
      namespaced: true,
      getters: {
        getTeams: () => [],
      },
      actions: {
        get: vi.fn(),
      },
    },
  },
});

vi.spyOn(store, 'dispatch');

describe('Monitoring.vue', () => {
  beforeEach(() => {
    mockEmitterCallbacks.clear();
    mockFetchSnapshot.mockClear();
    store.dispatch.mockClear();
  });

  it('fetches the monitoring snapshot on mount', () => {
    shallowMount(Monitoring, {
      global: {
        plugins: [store],
        stubs: {
          ReportHeader: true,
          MonitoringSummary: true,
          MonitoringInboxes: true,
          MonitoringAgents: true,
          Button: true,
          ButtonGroup: true,
          SelectMenu: true,
          Spinner: true,
        },
      },
    });

    expect(store.dispatch).toHaveBeenCalledWith(
      'monitoringReports/fetchSnapshot'
    );
  });

  it('refreshes when websocket monitoring events are emitted', () => {
    shallowMount(Monitoring, {
      global: {
        plugins: [store],
        stubs: {
          ReportHeader: true,
          MonitoringSummary: true,
          MonitoringInboxes: true,
          MonitoringAgents: true,
          Button: true,
          ButtonGroup: true,
          SelectMenu: true,
          Spinner: true,
        },
      },
    });

    expect(mockEmitterCallbacks.has('monitoring:refresh_snapshot')).toBe(true);

    mockEmitterCallbacks.get('monitoring:refresh_snapshot')();

    expect(store.dispatch).toHaveBeenCalledWith(
      'monitoringReports/fetchSnapshot'
    );
  });
});
