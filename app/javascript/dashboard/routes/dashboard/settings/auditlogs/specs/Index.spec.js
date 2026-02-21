import { shallowMount } from '@vue/test-utils';
import { ref, computed } from 'vue';
import Index from '../Index.vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';

// ---------------------------------------------------------------------------
// Mocks globais
// ---------------------------------------------------------------------------
vi.mock('dashboard/composables/store');
vi.mock('vue-router', async (importOriginal) => {
  const actual = await importOriginal();
  return {
    ...actual,
    useRoute: () => ({ query: { page: '1' } }),
    useRouter: () => ({ push: vi.fn() }),
  };
});
vi.mock('vue-i18n', async (importOriginal) => {
  const actual = await importOriginal();
  return {
    ...actual,
    useI18n: () => ({
      t: (key, payload) => {
        if (payload) return `[${key}:${JSON.stringify(payload)}]`;
        return `[${key}]`;
      },
    }),
  };
});
vi.mock('dashboard/composables', async (importOriginal) => {
  const actual = await importOriginal();
  return {
    ...actual,
    useAlert: vi.fn(),
  };
});
vi.mock('shared/helpers/timeHelper', async (importOriginal) => {
  const actual = await importOriginal();
  return {
    ...actual,
    messageTimestamp: (ts) => `ts:${ts}`,
  };
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function makeRecord(overrides = {}) {
  return {
    id: Math.random(),
    auditable_type: 'Inbox',
    action: 'create',
    user_id: 1,
    auditable_id: 42,
    audited_changes: {},
    auditable: null,
    created_at: 1700000000,
    remote_address: '127.0.0.1',
    ...overrides,
  };
}

function mountIndex(records = []) {
  const store = { dispatch: vi.fn() };
  const getters = {
    'auditlogs/getAuditLogs': computed(() => records),
    'auditlogs/getUIFlags': computed(() => ({ fetchingList: false })),
    'auditlogs/getMeta': computed(() => ({
      currentPage: 1,
      totalEntries: records.length,
      perPage: 25,
    })),
    'agents/getAgents': computed(() => [
      { id: 1, name: 'Ana Silva' },
      { id: 2, name: 'Carlos Souza' },
    ]),
  };

  useStore.mockReturnValue(store);
  useStoreGetters.mockReturnValue(getters);

  return shallowMount(Index);
}

// ===========================================================================
// Testes
// ===========================================================================
describe('AuditLog Index.vue', () => {
  // -----------------------------------------------------------------------
  // Estado vazio
  // -----------------------------------------------------------------------
  describe('quando não há registros', () => {
    it('exibe mensagem 404 e não renderiza tabela', () => {
      const wrapper = mountIndex([]);
      expect(wrapper.find('table').exists()).toBe(false);
      expect(wrapper.find('p').exists()).toBe(true);
    });
  });

  // -----------------------------------------------------------------------
  // Registros com tipos conhecidos
  // -----------------------------------------------------------------------
  describe('quando há registros válidos', () => {
    it('renderiza tabela com os registros', () => {
      const records = [
        makeRecord({ auditable_type: 'Inbox', action: 'create' }),
        makeRecord({ auditable_type: 'Team', action: 'update' }),
      ];
      const wrapper = mountIndex(records);
      expect(wrapper.find('table').exists()).toBe(true);
      expect(wrapper.findAll('tbody tr')).toHaveLength(2);
    });

    it('não exibe mensagem 404', () => {
      const records = [makeRecord({ auditable_type: 'Inbox', action: 'create' })];
      const wrapper = mountIndex(records);
      expect(wrapper.find('p').exists()).toBe(false);
    });
  });

  // -----------------------------------------------------------------------
  // Filtragem de registros inválidos (tipo desconhecido)
  // -----------------------------------------------------------------------
  describe('filtro validRecords', () => {
    it('filtra registros com auditable_type desconhecido', () => {
      const records = [
        makeRecord({ auditable_type: 'Profile', action: 'update' }), // desconhecido
        makeRecord({ auditable_type: 'Inbox', action: 'create' }),   // válido
      ];
      const wrapper = mountIndex(records);
      expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    });

    it('exibe mensagem 404 quando todos os registros são inválidos', () => {
      const records = [
        makeRecord({ auditable_type: 'Profile', action: 'update' }),
        makeRecord({ auditable_type: 'Unknown', action: 'create' }),
      ];
      const wrapper = mountIndex(records);
      expect(wrapper.find('table').exists()).toBe(false);
      expect(wrapper.find('p').exists()).toBe(true);
    });

    it('filtra accountuser:update quando única mudança é availability (duplicata)', () => {
      const records = [
        makeRecord({
          auditable_type: 'AccountUser',
          action: 'update',
          user_id: 1,
          audited_changes: { availability: [0, 1] }, // somente availability → suprimido
          auditable: { user_id: 1 },
        }),
        makeRecord({ auditable_type: 'Inbox', action: 'create' }), // válido
      ];
      const wrapper = mountIndex(records);
      // Apenas 1 linha visível (a duplicata está suprimida)
      expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    });

    it('mantém accountuser:update com role + availability (não é duplicata)', () => {
      const records = [
        makeRecord({
          auditable_type: 'AccountUser',
          action: 'update',
          user_id: 1,
          audited_changes: { availability: [0, 2], role: [0, 1] },
          auditable: { user_id: 1 },
        }),
      ];
      const wrapper = mountIndex(records);
      expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    });

    it('mantém user:availability_change (original, não duplicata)', () => {
      const records = [
        makeRecord({
          auditable_type: 'User',
          action: 'availability_change',
          user_id: 1,
          audited_changes: {
            availability_from: 0,
            availability_to: 1,
            reason: 'manual',
          },
        }),
      ];
      const wrapper = mountIndex(records);
      expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    });

    it('filtra mix de válidos e inválidos corretamente', () => {
      const records = [
        makeRecord({ auditable_type: 'Profile', action: 'update' }),  // inválido
        makeRecord({ auditable_type: 'Inbox', action: 'create' }),    // válido
        makeRecord({ auditable_type: 'Unknown', action: 'create' }), // inválido
        makeRecord({ auditable_type: 'Team', action: 'destroy' }),   // válido
        makeRecord({                                                   // inválido (duplicata)
          auditable_type: 'AccountUser',
          action: 'update',
          user_id: 1,
          audited_changes: { availability: [0, 1] },
          auditable: { user_id: 1 },
        }),
        makeRecord({ auditable_type: 'Webhook', action: 'create' }),  // válido
      ];
      const wrapper = mountIndex(records);
      expect(wrapper.findAll('tbody tr')).toHaveLength(3);
    });
  });

  // -----------------------------------------------------------------------
  // Estado de loading
  // -----------------------------------------------------------------------
  describe('estado de carregamento', () => {
    it('não exibe tabela nem mensagem 404 durante fetchingList', () => {
      const store = { dispatch: vi.fn() };
      const getters = {
        'auditlogs/getAuditLogs': computed(() => []),
        'auditlogs/getUIFlags': computed(() => ({ fetchingList: true })),
        'auditlogs/getMeta': computed(() => ({ currentPage: 1, totalEntries: 0, perPage: 25 })),
        'agents/getAgents': computed(() => []),
      };
      useStore.mockReturnValue(store);
      useStoreGetters.mockReturnValue(getters);

      const wrapper = shallowMount(Index);
      expect(wrapper.find('table').exists()).toBe(false);
      // Enquanto carregando, a mensagem 404 não deve aparecer
      // (v-else-if="!validRecords.length" só avalia quando fetchingList=false)
      expect(wrapper.find('p').exists()).toBe(false);
    });
  });

  // -----------------------------------------------------------------------
  // Dispatch na montagem
  // -----------------------------------------------------------------------
  describe('onMounted', () => {
    it('executa dispatch de agents/get e auditlogs/fetch ao montar', () => {
      const store = { dispatch: vi.fn() };
      const getters = {
        'auditlogs/getAuditLogs': computed(() => []),
        'auditlogs/getUIFlags': computed(() => ({ fetchingList: false })),
        'auditlogs/getMeta': computed(() => ({ currentPage: 1, totalEntries: 0, perPage: 25 })),
        'agents/getAgents': computed(() => []),
      };
      useStore.mockReturnValue(store);
      useStoreGetters.mockReturnValue(getters);

      shallowMount(Index);

      expect(store.dispatch).toHaveBeenCalledWith('agents/get');
      expect(store.dispatch).toHaveBeenCalledWith('auditlogs/fetch', { page: 1 });
    });
  });
});
