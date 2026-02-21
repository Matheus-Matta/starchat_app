import {
  extractChangedAccountUserValues,
  generateTranslationPayload,
  generateLogActionKey,
} from '../auditlogHelper';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
const agentList = [
  { id: 1, name: 'Ana Silva' },
  { id: 2, name: 'Carlos Souza' },
  { id: 3, name: 'Beatriz Lima' },
];

function makeAuditLog(overrides = {}) {
  return {
    auditable_type: 'User',
    action: 'sign_in',
    user_id: 1,
    auditable_id: 10,
    audited_changes: {},
    auditable: null,
    ...overrides,
  };
}

// ===========================================================================
// extractChangedAccountUserValues
// ===========================================================================
describe('extractChangedAccountUserValues', () => {
  it('extrai role agent → administrator', () => {
    const { changes, values } = extractChangedAccountUserValues({ role: [0, 1] });
    expect(changes).toEqual(['role']);
    expect(values).toEqual(['administrator']);
  });

  it('extrai role administrator → agent', () => {
    const { changes, values } = extractChangedAccountUserValues({ role: [1, 0] });
    expect(changes).toEqual(['role']);
    expect(values).toEqual(['agent']);
  });

  it('extrai availability online → busy', () => {
    const { changes, values } = extractChangedAccountUserValues({ availability: [0, 2] });
    expect(changes).toEqual(['availability']);
    expect(values).toEqual(['busy']);
  });

  it('extrai availability offline → online', () => {
    const { changes, values } = extractChangedAccountUserValues({ availability: [1, 0] });
    expect(changes).toEqual(['availability']);
    expect(values).toEqual(['online']);
  });

  it('extrai availability busy → offline', () => {
    const { changes, values } = extractChangedAccountUserValues({ availability: [2, 1] });
    expect(changes).toEqual(['availability']);
    expect(values).toEqual(['offline']);
  });

  it('extrai ambos role e availability', () => {
    const { changes, values } = extractChangedAccountUserValues({
      role: [1, 0],
      availability: [0, 2],
    });
    expect(changes).toEqual(['role', 'availability']);
    expect(values).toEqual(['agent', 'busy']);
  });

  it('retorna arrays vazios para campos desconhecidos', () => {
    const { changes, values } = extractChangedAccountUserValues({ other: 'x' });
    expect(changes).toEqual([]);
    expect(values).toEqual([]);
  });

  it('retorna arrays vazios para objeto vazio', () => {
    const { changes, values } = extractChangedAccountUserValues({});
    expect(changes).toEqual([]);
    expect(values).toEqual([]);
  });
});

// ===========================================================================
// generateTranslationPayload
// ===========================================================================
describe('generateTranslationPayload', () => {
  // -----------------------------------------------------------------------
  // AccountUser create
  // -----------------------------------------------------------------------
  describe('AccountUser create', () => {
    it('monta payload com invitee e role administrator', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'create',
        user_id: 1,
        auditable_id: 99,
        audited_changes: { user_id: 2, role: 1 },
      });
      expect(generateTranslationPayload(item, agentList)).toEqual({
        agentName: 'Ana Silva',
        id: 99,
        invitee: 'Carlos Souza',
        role: 'administrator',
      });
    });

    it('monta payload com invitee e role agent', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'create',
        user_id: 1,
        auditable_id: 100,
        audited_changes: { user_id: 3, role: 0 },
      });
      expect(generateTranslationPayload(item, agentList)).toEqual({
        agentName: 'Ana Silva',
        id: 100,
        invitee: 'Beatriz Lima',
        role: 'agent',
      });
    });
  });

  // -----------------------------------------------------------------------
  // AccountUser update
  // -----------------------------------------------------------------------
  describe('AccountUser update', () => {
    it('inclui user no payload para edição de outro agente', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        auditable_id: 55,
        audited_changes: { role: [0, 1], availability: [1, 2] },
        auditable: { user_id: 2 },
      });
      const payload = generateTranslationPayload(item, agentList);
      expect(payload.agentName).toBe('Ana Silva');
      expect(payload.user).toBe('Carlos Souza');
      expect(payload.attributes).toEqual(['role', 'availability']);
      expect(payload.values).toEqual(['administrator', 'busy']);
    });

    it('não inclui user no payload para edição própria', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        auditable_id: 55,
        audited_changes: { role: [0, 1] },
        auditable: { user_id: 1 },
      });
      const payload = generateTranslationPayload(item, agentList);
      expect(payload.user).toBeUndefined();
      expect(payload.attributes).toEqual(['role']);
      expect(payload.values).toEqual(['administrator']);
    });
  });

  // -----------------------------------------------------------------------
  // InboxMember / TeamMember
  // -----------------------------------------------------------------------
  describe('InboxMember / TeamMember', () => {
    it('monta payload com user para InboxMember create', () => {
      const item = makeAuditLog({
        auditable_type: 'InboxMember',
        action: 'create',
        user_id: 1,
        auditable_id: 77,
        audited_changes: { user_id: 3 },
      });
      expect(generateTranslationPayload(item, agentList)).toEqual({
        agentName: 'Ana Silva',
        id: 77,
        user: 'Beatriz Lima',
      });
    });

    it('monta payload com user para TeamMember destroy', () => {
      const item = makeAuditLog({
        auditable_type: 'TeamMember',
        action: 'destroy',
        user_id: 2,
        auditable_id: 88,
        audited_changes: { user_id: 3 },
      });
      expect(generateTranslationPayload(item, agentList)).toEqual({
        agentName: 'Carlos Souza',
        id: 88,
        user: 'Beatriz Lima',
      });
    });
  });

  // -----------------------------------------------------------------------
  // Genérico
  // -----------------------------------------------------------------------
  describe('Entidades genéricas', () => {
    it.each([
      ['Team', 'create'],
      ['Inbox', 'update'],
      ['Webhook', 'destroy'],
      ['AutomationRule', 'create'],
      ['Macro', 'update'],
    ])('%s %s inclui agentName e id', (type, action) => {
      const item = makeAuditLog({ auditable_type: type, action, user_id: 1, auditable_id: 42 });
      expect(generateTranslationPayload(item, agentList)).toEqual({
        agentName: 'Ana Silva',
        id: 42,
      });
    });
  });

  // -----------------------------------------------------------------------
  // Conversation destroy — usa display_id
  // -----------------------------------------------------------------------
  describe('Conversation destroy', () => {
    it('usa display_id quando presente em audited_changes', () => {
      const item = makeAuditLog({
        auditable_type: 'Conversation',
        action: 'destroy',
        user_id: 1,
        auditable_id: 500,
        audited_changes: { display_id: 42 },
      });
      expect(generateTranslationPayload(item, agentList).id).toBe(42);
    });

    it('usa auditable_id como fallback sem display_id', () => {
      const item = makeAuditLog({
        auditable_type: 'Conversation',
        action: 'destroy',
        user_id: 1,
        auditable_id: 500,
        audited_changes: {},
      });
      expect(generateTranslationPayload(item, agentList).id).toBe(500);
    });
  });

  // -----------------------------------------------------------------------
  // user:availability_change — from / to / reason
  // -----------------------------------------------------------------------
  describe('user availability_change', () => {
    function makeAvailability(changes = {}) {
      return makeAuditLog({
        auditable_type: 'User',
        action: 'availability_change',
        user_id: 1,
        auditable_id: 1,
        audited_changes: {
          availability_from: 0,
          availability_to: 1,
          reason: 'manual',
          ...changes,
        },
      });
    }

    // from / to
    it.each([
      [0, 1, 'online', 'offline'],
      [0, 2, 'online', 'busy'],
      [2, 0, 'busy', 'online'],
      [1, 0, 'offline', 'online'],
      [2, 1, 'busy', 'offline'],
    ])('from=%i to=%i → %s / %s', (from, to, expFrom, expTo) => {
      const payload = generateTranslationPayload(makeAvailability({ availability_from: from, availability_to: to }), agentList);
      expect(payload.from).toBe(expFrom);
      expect(payload.to).toBe(expTo);
    });

    // reason → label pt-BR
    it.each([
      ['manual', 'manualmente'],
      ['connection_lost', 'conexão perdida'],
      ['browser_closed', 'navegador fechado'],
      ['session_expired', 'sessão expirada'],
      ['auto_offline', 'offline automático'],
    ])('reason %s → "%s"', (reason, expected) => {
      const payload = generateTranslationPayload(makeAvailability({ reason }), agentList);
      expect(payload.reason).toBe(expected);
    });

    it('usa raw reason como fallback para código desconhecido', () => {
      const payload = generateTranslationPayload(makeAvailability({ reason: 'xyz_reason' }), agentList);
      expect(payload.reason).toBe('xyz_reason');
    });

    it('usa "manualmente" quando reason não está definido', () => {
      const item = makeAuditLog({
        auditable_type: 'User',
        action: 'availability_change',
        user_id: 1,
        audited_changes: { availability_from: 0, availability_to: 1 },
      });
      expect(generateTranslationPayload(item, agentList).reason).toBe('manualmente');
    });

    it('usa raw value para from/to fora do mapeamento', () => {
      const payload = generateTranslationPayload(makeAvailability({ availability_from: 99, availability_to: 'x' }), agentList);
      expect(payload.from).toBe(99);
      expect(payload.to).toBe('x');
    });

    it('não quebra quando audited_changes é undefined', () => {
      const item = makeAuditLog({
        auditable_type: 'User',
        action: 'availability_change',
        user_id: 1,
        audited_changes: undefined,
      });
      expect(() => generateTranslationPayload(item, agentList)).not.toThrow();
    });

    it('inclui agentName correto', () => {
      const payload = generateTranslationPayload(makeAvailability(), agentList);
      expect(payload.agentName).toBe('Ana Silva');
    });
  });

  // -----------------------------------------------------------------------
  // agentName fallbacks
  // -----------------------------------------------------------------------
  describe('agentName fallbacks', () => {
    it('usa "System" quando user_id é null', () => {
      const item = makeAuditLog({ user_id: null });
      expect(generateTranslationPayload(item, agentList).agentName).toBe('System');
    });

    it('usa user_id como fallback quando agente não está na lista', () => {
      const item = makeAuditLog({ user_id: 999 });
      expect(generateTranslationPayload(item, agentList).agentName).toBe(999);
    });

    it.each([
      [1, 'Ana Silva'],
      [2, 'Carlos Souza'],
      [3, 'Beatriz Lima'],
    ])('user_id=%i → %s', (id, name) => {
      expect(generateTranslationPayload(makeAuditLog({ user_id: id }), agentList).agentName).toBe(name);
    });
  });
});

// ===========================================================================
// generateLogActionKey
// ===========================================================================
describe('generateLogActionKey', () => {
  // -----------------------------------------------------------------------
  // Todos os tipos conhecidos
  // -----------------------------------------------------------------------
  describe('tipos conhecidos', () => {
    it.each([
      [{ auditable_type: 'AutomationRule', action: 'create' }, 'AUDIT_LOGS.AUTOMATION_RULE.ADD'],
      [{ auditable_type: 'AutomationRule', action: 'update' }, 'AUDIT_LOGS.AUTOMATION_RULE.EDIT'],
      [{ auditable_type: 'AutomationRule', action: 'destroy' }, 'AUDIT_LOGS.AUTOMATION_RULE.DELETE'],
      [{ auditable_type: 'Webhook', action: 'create' }, 'AUDIT_LOGS.WEBHOOK.ADD'],
      [{ auditable_type: 'Webhook', action: 'update' }, 'AUDIT_LOGS.WEBHOOK.EDIT'],
      [{ auditable_type: 'Webhook', action: 'destroy' }, 'AUDIT_LOGS.WEBHOOK.DELETE'],
      [{ auditable_type: 'Inbox', action: 'create' }, 'AUDIT_LOGS.INBOX.ADD'],
      [{ auditable_type: 'Inbox', action: 'update' }, 'AUDIT_LOGS.INBOX.EDIT'],
      [{ auditable_type: 'Inbox', action: 'destroy' }, 'AUDIT_LOGS.INBOX.DELETE'],
      [{ auditable_type: 'User', action: 'sign_in' }, 'AUDIT_LOGS.USER_ACTION.SIGN_IN'],
      [{ auditable_type: 'User', action: 'availability_change' }, 'AUDIT_LOGS.USER_ACTION.AVAILABILITY_CHANGE'],
      [{ auditable_type: 'Team', action: 'create' }, 'AUDIT_LOGS.TEAM.ADD'],
      [{ auditable_type: 'Team', action: 'update' }, 'AUDIT_LOGS.TEAM.EDIT'],
      [{ auditable_type: 'Team', action: 'destroy' }, 'AUDIT_LOGS.TEAM.DELETE'],
      [{ auditable_type: 'Macro', action: 'create' }, 'AUDIT_LOGS.MACRO.ADD'],
      [{ auditable_type: 'Macro', action: 'update' }, 'AUDIT_LOGS.MACRO.EDIT'],
      [{ auditable_type: 'Macro', action: 'destroy' }, 'AUDIT_LOGS.MACRO.DELETE'],
      [{ auditable_type: 'Account', action: 'update' }, 'AUDIT_LOGS.ACCOUNT.EDIT'],
      [{ auditable_type: 'Conversation', action: 'destroy' }, 'AUDIT_LOGS.CONVERSATION.DELETE'],
      [{ auditable_type: 'InboxMember', action: 'create' }, 'AUDIT_LOGS.INBOX_MEMBER.ADD'],
      [{ auditable_type: 'InboxMember', action: 'destroy' }, 'AUDIT_LOGS.INBOX_MEMBER.REMOVE'],
      [{ auditable_type: 'TeamMember', action: 'create' }, 'AUDIT_LOGS.TEAM_MEMBER.ADD'],
      [{ auditable_type: 'TeamMember', action: 'destroy' }, 'AUDIT_LOGS.TEAM_MEMBER.REMOVE'],
      [{ auditable_type: 'AccountUser', action: 'create' }, 'AUDIT_LOGS.ACCOUNT_USER.ADD'],
    ])('%o → %s', (fields, expected) => {
      expect(generateLogActionKey(makeAuditLog(fields))).toBe(expected);
    });
  });

  // -----------------------------------------------------------------------
  // Tipos desconhecidos → string vazia
  // -----------------------------------------------------------------------
  describe('tipos/ações desconhecidos', () => {
    it.each([
      ['Profile', 'update'],
      ['User', 'destroy'],
      ['Conversation', 'update'],
      ['Unknown', 'create'],
      ['Inbox', 'archive'],
      ['Team', 'delete'],
    ])('%s:%s → "" (linha filtrada)', (type, action) => {
      expect(generateLogActionKey(makeAuditLog({ auditable_type: type, action }))).toBe('');
    });
  });

  // -----------------------------------------------------------------------
  // AccountUser update — self / other / deleted
  // -----------------------------------------------------------------------
  describe('AccountUser update', () => {
    it('retorna EDIT.SELF quando user edita a si mesmo', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { role: [0, 1] },
        auditable: { user_id: 1 },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF');
    });

    it('retorna EDIT.OTHER quando user edita outro agente', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { role: [0, 1] },
        auditable: { user_id: 2 },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.OTHER');
    });

    it('retorna EDIT.DELETED quando auditable é null', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { role: [0, 1] },
        auditable: null,
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.DELETED');
    });
  });

  // -----------------------------------------------------------------------
  // Supressão de duplicata — accountuser:update com SOMENTE availability
  // -----------------------------------------------------------------------
  describe('supressão de duplicata: only availability change', () => {
    it('retorna "" quando única mudança é availability (self)', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { availability: [0, 1] },
        auditable: { user_id: 1 },
      });
      expect(generateLogActionKey(item)).toBe('');
    });

    it('retorna "" quando única mudança é availability (other)', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { availability: [1, 2] },
        auditable: { user_id: 2 },
      });
      expect(generateLogActionKey(item)).toBe('');
    });

    it('retorna "" quando única mudança é availability (deleted)', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { availability: [0, 2] },
        auditable: null,
      });
      expect(generateLogActionKey(item)).toBe('');
    });

    it('NÃO suprime quando availability + role mudam', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { availability: [0, 2], role: [0, 1] },
        auditable: { user_id: 1 },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF');
    });

    it('NÃO suprime quando apenas role muda', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { role: [0, 1] },
        auditable: { user_id: 1 },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF');
    });

    it('NÃO suprime quando há 3+ campos mudados', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: { availability: [0, 2], role: [0, 1], auto_offline: [true, false] },
        auditable: { user_id: 1 },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF');
    });

    it('NÃO suprime quando audited_changes está vazio', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        user_id: 1,
        audited_changes: {},
        auditable: { user_id: 1 },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF');
    });
  });

  // -----------------------------------------------------------------------
  // user:sign_out — variantes de logout_reason
  // -----------------------------------------------------------------------
  describe('user sign_out com logout_reason', () => {
    it.each([
      ['manual', 'AUDIT_LOGS.USER_ACTION.SIGN_OUT_MANUAL'],
      ['browser_closed', 'AUDIT_LOGS.USER_ACTION.SIGN_OUT_BROWSER_CLOSED'],
      ['session_expired', 'AUDIT_LOGS.USER_ACTION.SIGN_OUT_SESSION_EXPIRED'],
    ])('logout_reason=%s → %s', (reason, expected) => {
      const item = makeAuditLog({
        auditable_type: 'User',
        action: 'sign_out',
        audited_changes: { logout_reason: reason },
      });
      expect(generateLogActionKey(item)).toBe(expected);
    });

    it('retorna SIGN_OUT base para logout_reason desconhecido', () => {
      const item = makeAuditLog({
        auditable_type: 'User',
        action: 'sign_out',
        audited_changes: { logout_reason: 'force_unknown' },
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.USER_ACTION.SIGN_OUT');
    });

    it('retorna SIGN_OUT base quando logout_reason ausente', () => {
      const item = makeAuditLog({
        auditable_type: 'User',
        action: 'sign_out',
        audited_changes: {},
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.USER_ACTION.SIGN_OUT');
    });

    it('retorna SIGN_OUT base quando audited_changes é null', () => {
      const item = makeAuditLog({
        auditable_type: 'User',
        action: 'sign_out',
        audited_changes: null,
      });
      expect(generateLogActionKey(item)).toBe('AUDIT_LOGS.USER_ACTION.SIGN_OUT');
    });
  });

  // -----------------------------------------------------------------------
  // Case insensitivity
  // -----------------------------------------------------------------------
  describe('normalização de case', () => {
    it('normaliza auditable_type em maiúsculas', () => {
      expect(generateLogActionKey(makeAuditLog({ auditable_type: 'INBOX', action: 'create' }))).toBe('AUDIT_LOGS.INBOX.ADD');
    });

    it('normaliza action em maiúsculas', () => {
      expect(generateLogActionKey(makeAuditLog({ auditable_type: 'Inbox', action: 'CREATE' }))).toBe('AUDIT_LOGS.INBOX.ADD');
    });
  });

  // -----------------------------------------------------------------------
  // hasValidLogText — comportamento implícito de filtro
  // -----------------------------------------------------------------------
  describe('hasValidLogText (via generateLogActionKey)', () => {
    it('retorna truthy para evento conhecido', () => {
      const item = makeAuditLog({ auditable_type: 'Inbox', action: 'create' });
      expect(!!generateLogActionKey(item)).toBe(true);
    });

    it('retorna falsy para evento desconhecido (filtro de linha em branco)', () => {
      const item = makeAuditLog({ auditable_type: 'Profile', action: 'update' });
      expect(!!generateLogActionKey(item)).toBe(false);
    });

    it('retorna falsy para accountuser:update com only availability (duplicata suprimida)', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        audited_changes: { availability: [0, 1] },
        auditable: { user_id: 1 },
        user_id: 1,
      });
      expect(!!generateLogActionKey(item)).toBe(false);
    });

    it('retorna truthy para accountuser:update com role (não suprimido)', () => {
      const item = makeAuditLog({
        auditable_type: 'AccountUser',
        action: 'update',
        audited_changes: { role: [0, 1] },
        auditable: { user_id: 1 },
        user_id: 1,
      });
      expect(!!generateLogActionKey(item)).toBe(true);
    });
  });
});
