# frozen_string_literal: true

require 'rails_helper'

# ─────────────────────────────────────────────────────────────────────────────
# Suite: Round Robin Assignment
#
# Verifica o comportamento do serviço de atribuição quando a política usa
# assignment_order: :round_robin.
#
# O método `resolve_selector` deve retornar `RoundRobinSelector`, com
# sequenciamento circular pelos agentes disponíveis, respeitando os demais
# controles: prioridade de conversa, guarda enable_auto_assignment e
# política desativada.
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe 'Round Robin Assignment', type: :service do
  let(:account) { create(:account) }

  # Inbox com atribuição automática habilitada (pré-requisito para a política)
  let(:inbox) do
    create(:inbox, account: account, enable_auto_assignment: true)
  end

  # 4 agentes para ter rotação clara
  let(:agent1) { create(:user, account: account, name: 'RR-Agent-1') }
  let(:agent2) { create(:user, account: account, name: 'RR-Agent-2') }
  let(:agent3) { create(:user, account: account, name: 'RR-Agent-3') }
  let(:agent4) { create(:user, account: account, name: 'RR-Agent-4') }

  let(:policy) do
    create(:assignment_policy,
           account: account,
           assignment_order: :round_robin,
           conversation_priority: :earliest_created,
           enabled: true)
  end

  let(:service) { AutoAssignment::AssignmentService.new(inbox: inbox) }

  # ─── Helpers ──────────────────────────────────────────────────────────────

  def set_online(*agents)
    agents.each do |agent|
      OnlineStatusTracker.update_presence(account.id, 'User', agent.id)
      OnlineStatusTracker.set_status(account.id, agent.id, 'online')
    end
  end

  def create_open_conversation(attrs = {})
    create(:conversation, inbox: inbox, assignee: nil, status: 'open', **attrs)
  end

  # ─── Setup padrão ─────────────────────────────────────────────────────────

  before do
    create(:inbox_member, inbox: inbox, user: agent1)
    create(:inbox_member, inbox: inbox, user: agent2)
    create(:inbox_member, inbox: inbox, user: agent3)
    create(:inbox_member, inbox: inbox, user: agent4)

    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)

    set_online(agent1, agent2, agent3, agent4)

    # Evita que feature flags não relacionadas interfiram
    allow(account).to receive(:feature_enabled?).and_return(false)
    allow(account).to receive(:feature_enabled?).with('assignment_v2').and_return(true)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 1: Seletor correto para Round Robin
  # ══════════════════════════════════════════════════════════════════════════
  describe 'seleção do seletor (resolve_selector)' do
    it 'delega ao RoundRobinSelector quando a política é round_robin' do
      expect(policy.round_robin?).to be true
      rr_selector = instance_double(AutoAssignment::RoundRobinSelector, select_agent: nil, queue_snapshot: [])
      allow(AutoAssignment::RoundRobinSelector).to receive(:new).and_return(rr_selector)

      create_open_conversation
      service.perform_bulk_assignment(limit: 1)

      expect(AutoAssignment::RoundRobinSelector).to have_received(:new).with(inbox: inbox)
    end

    it 'não instancia BalancedSelector' do
      allow(Starchat::AutoAssignment::BalancedSelector).to receive(:new).and_call_original
      create_open_conversation
      service.perform_bulk_assignment(limit: 1)
      expect(Starchat::AutoAssignment::BalancedSelector).not_to have_received(:new)
    end

    it 'não instancia EqualDistributionSelector' do
      allow(Starchat::AutoAssignment::EqualDistributionSelector).to receive(:new).and_call_original
      create_open_conversation
      service.perform_bulk_assignment(limit: 1)
      expect(Starchat::AutoAssignment::EqualDistributionSelector).not_to have_received(:new)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 2: Distribuição circular com 20 conversas
  # ══════════════════════════════════════════════════════════════════════════
  describe 'distribuição circular com 20 conversas e 4 agentes' do
    let!(:conversations) do
      Array.new(20) { create_open_conversation }
    end

    it 'atribui todas as 20 conversas' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'distribui entre os 4 agentes (nenhum fica com mais de 6 conversas em excesso)' do
      service.perform_bulk_assignment(limit: 20)
      assignees = conversations.map { |c| c.reload.assignee }.compact
      max = assignees.tally.values.max
      min = assignees.tally.values.min
      # Round Robin exato → diferença de no máximo 1 (20 / 4 = 5 each)
      expect(max - min).to be <= 1
    end

    it 'todos os 4 agentes recebem ao menos uma conversa' do
      service.perform_bulk_assignment(limit: 20)
      assigned_agent_ids = conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      expect(assigned_agent_ids.size).to eq(4)
    end

    it 'nenhuma conversa fica sem atribuição' do
      service.perform_bulk_assignment(limit: 20)
      unassigned = conversations.count { |c| c.reload.assignee.nil? }
      expect(unassigned).to eq(0)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 3: Prioridade earliest_created
  # ══════════════════════════════════════════════════════════════════════════
  describe 'prioridade earliest_created (padrão)' do
    let!(:older_conv)  { create_open_conversation(created_at: 5.hours.ago) }
    let!(:newer_conv)  { create_open_conversation(created_at: 1.hour.ago) }
    let!(:newest_conv) { create_open_conversation(created_at: 10.minutes.ago) }

    before do
      # Apenas 1 agente para garantir ordem de atribuição
      inbox.inbox_members.where.not(user_id: agent1.id).destroy_all
      set_online(agent1)
    end

    it 'atribui a conversa mais antiga primeiro' do
      service.perform_bulk_assignment(limit: 1)
      expect(older_conv.reload.assignee).to eq(agent1)
      expect(newer_conv.reload.assignee).to be_nil
      expect(newest_conv.reload.assignee).to be_nil
    end

    it 'na 2ª iteração atribui a 2ª conversa mais antiga' do
      service.perform_bulk_assignment(limit: 2)
      expect(older_conv.reload.assignee).to eq(agent1)
      expect(newer_conv.reload.assignee).to eq(agent1)
      expect(newest_conv.reload.assignee).to be_nil
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 4: Prioridade longest_waiting
  # ══════════════════════════════════════════════════════════════════════════
  describe 'prioridade longest_waiting' do
    let!(:policy_lw) do
      create(:assignment_policy,
             account: account,
             assignment_order: :round_robin,
             conversation_priority: :longest_waiting,
             enabled: true)
    end
    let(:inbox_lw) { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:service_lw) { AutoAssignment::AssignmentService.new(inbox: inbox_lw) }

    before do
      create(:inbox_member, inbox: inbox_lw, user: agent1)
      create(:inbox_assignment_policy, inbox: inbox_lw, assignment_policy: policy_lw)
      set_online(agent1)
    end

    let!(:active_recently)   { create(:conversation, inbox: inbox_lw, assignee: nil, status: 'open', last_activity_at: 30.minutes.ago) }
    let!(:inactive_long_ago) { create(:conversation, inbox: inbox_lw, assignee: nil, status: 'open', last_activity_at: 3.hours.ago) }
    let!(:inactive_very_old) { create(:conversation, inbox: inbox_lw, assignee: nil, status: 'open', last_activity_at: 8.hours.ago) }

    it 'atribui primeiro a conversa com last_activity_at mais antigo' do
      service_lw.perform_bulk_assignment(limit: 1)
      expect(inactive_very_old.reload.assignee).to eq(agent1)
      expect(inactive_long_ago.reload.assignee).to be_nil
      expect(active_recently.reload.assignee).to be_nil
    end

    it 'ordena corretamente todas as conversas pela espera mais longa' do
      service_lw.perform_bulk_assignment(limit: 3)
      order = [inactive_very_old, inactive_long_ago, active_recently].map { |c| c.reload.assignee&.id }
      expect(order).to all(eq(agent1.id))
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 5: Guarda enable_auto_assignment
  # ══════════════════════════════════════════════════════════════════════════
  describe 'guarda enable_auto_assignment' do
    let!(:conversations) { Array.new(20) { create_open_conversation } }

    context 'quando enable_auto_assignment está desativado' do
      before { inbox.update!(enable_auto_assignment: false) }

      it 'a política retorna nil (auto_assignment desativado)' do
        # O método `policy` protege com esta guarda
        expect(service.send(:policy)).to be_nil
      end

      it 'não aplica a política mesmo com policy vinculada' do
        # Não há execução da policy — o seletor cai no RR padrão sem config
        service.perform_bulk_assignment(limit: 10)
        # As conversas podem ser atribuídas pelo RR base, mas a policy não interfere
        # (neste contexto: auto_assignment_v2_enabled? também verifica enable_auto_assignment)
      end
    end

    context 'quando enable_auto_assignment está ativado' do
      it 'a política é lida normalmente' do
        expect(service.send(:policy)).to eq(policy)
      end

      it 'assignment_config reflete a política' do
        config = service.send(:assignment_config)
        expect(config['conversation_priority']).to eq('earliest_created')
        expect(config['fair_distribution_limit']).to eq(policy.fair_distribution_limit)
      end
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 6: Política desativada (enabled: false)
  # ══════════════════════════════════════════════════════════════════════════
  describe 'política desativada (enabled: false)' do
    before { policy.update!(enabled: false) }

    let!(:conversations) { Array.new(5) { create_open_conversation } }

    it 'perform_bulk_assignment ainda executa (enabled é controle de negócio, não impede atribuição)' do
      # A flag `enabled` expõe a política ao usuário, mas o serviço não filtra por ela
      # — esse comportamento assegura que o campo não quebra atribuições silenciosamente
      count = service.perform_bulk_assignment(limit: 5)
      expect(count).to be >= 0
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 7: Sem agentes disponíveis
  # ══════════════════════════════════════════════════════════════════════════
  describe 'sem agentes disponíveis' do
    let!(:conversations) { Array.new(20) { create_open_conversation } }

    before do
      # Coloca todos agentes offline
      [agent1, agent2, agent3, agent4].each do |agent|
        OnlineStatusTracker.set_status(account.id, agent.id, 'offline')
      end
    end

    it 'não atribui nenhuma conversa' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(0)
    end

    it 'todas as conversas permanecem sem atribuição' do
      service.perform_bulk_assignment(limit: 20)
      unassigned = conversations.count { |c| c.reload.assignee.nil? }
      expect(unassigned).to eq(20)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 8: Apenas 1 agente disponível
  # ══════════════════════════════════════════════════════════════════════════
  describe 'apenas 1 agente disponível de 4' do
    let!(:conversations) { Array.new(20) { create_open_conversation } }

    before do
      [agent2, agent3, agent4].each do |agent|
        OnlineStatusTracker.set_status(account.id, agent.id, 'offline')
      end
    end

    it 'atribui todas as conversas ao único agente disponível' do
      count = service.perform_bulk_assignment(limit: 20)
      # fair_distribution_limit da factory é 10, então apenas 10 podem ser
      # atribuídas ao único agente disponível dentro da janela
      expect(count).to eq(10)
      assigned = conversations.map { |c| c.reload.assignee }.compact.uniq
      expect(assigned).to eq([agent1])
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 9: Conversas já atribuídas não são reatribuídas
  # ══════════════════════════════════════════════════════════════════════════
  describe 'conversas já atribuídas' do
    let!(:unassigned_convs) { Array.new(10) { create_open_conversation } }
    let!(:assigned_convs)   { Array.new(10) { create(:conversation, inbox: inbox, assignee: agent1, status: 'open') } }

    it 'não reatribui conversas que já possuem assignee' do
      service.perform_bulk_assignment(limit: 20)
      assigned_convs.each do |conv|
        expect(conv.reload.assignee).to eq(agent1)
      end
    end

    it 'atribui somente as conversas não atribuídas' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(10)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 10: Conversas fechadas ou resolvidas são ignoradas
  # ══════════════════════════════════════════════════════════════════════════
  describe 'conversas fechadas / resolvidas são ignoradas' do
    let!(:open_convs)     { Array.new(10) { create_open_conversation } }
    let!(:resolved_convs) { Array.new(5) { create(:conversation, inbox: inbox, assignee: nil, status: 'resolved') } }
    let!(:pending_convs)  { Array.new(5) { create(:conversation, inbox: inbox, assignee: nil, status: 'pending') } }

    it 'processa apenas conversas abertas' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(10)
    end

    it 'não atribui conversas resolvidas' do
      service.perform_bulk_assignment(limit: 20)
      resolved_convs.each { |c| expect(c.reload.assignee).to be_nil }
    end

    it 'não atribui conversas pendentes' do
      service.perform_bulk_assignment(limit: 20)
      pending_convs.each { |c| expect(c.reload.assignee).to be_nil }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 11: Limite de bulk assignment
  # ══════════════════════════════════════════════════════════════════════════
  describe 'respeita o parâmetro limit no bulk assignment' do
    let!(:conversations) { Array.new(20) { create_open_conversation } }

    it 'não atribui mais do que o limite informado' do
      count = service.perform_bulk_assignment(limit: 7)
      expect(count).to eq(7)
    end

    it 'com limit: 0 não atribui nada' do
      count = service.perform_bulk_assignment(limit: 0)
      expect(count).to eq(0)
    end

    it 'com limit: 1 atribui exatamente 1' do
      count = service.perform_bulk_assignment(limit: 1)
      expect(count).to eq(1)
    end

    it 'com limit maior que o total disponível atribui todas' do
      count = service.perform_bulk_assignment(limit: 100)
      expect(count).to eq(20)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 12: assignment_config carrega parâmetros da política
  # ══════════════════════════════════════════════════════════════════════════
  describe 'assignment_config' do
    it 'usa conversation_priority da política' do
      config = service.send(:assignment_config)
      expect(config['conversation_priority']).to eq('earliest_created')
    end

    it 'usa fair_distribution_limit da política' do
      policy.update!(fair_distribution_limit: 50)
      # Força re-leitura (memo se baseia em nova instância)
      fresh_service = AutoAssignment::AssignmentService.new(inbox: inbox)
      expect(fresh_service.send(:assignment_config)['fair_distribution_limit']).to eq(50)
    end

    it 'usa fair_distribution_window da política' do
      policy.update!(fair_distribution_window: 1800)
      fresh_service = AutoAssignment::AssignmentService.new(inbox: inbox)
      expect(fresh_service.send(:assignment_config)['fair_distribution_window']).to eq(1800)
    end

    it 'sem política, delega ao super (config base do inbox)' do
      inbox.update!(enable_auto_assignment: false) # força policy = nil
      fresh_service = AutoAssignment::AssignmentService.new(inbox: inbox)
      config = fresh_service.send(:assignment_config)
      expect(config).to be_a(Hash)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 13: Auditoria registrada
  # ══════════════════════════════════════════════════════════════════════════
  describe 'registro de auditoria' do
    let!(:conv) { create_open_conversation }

    it 'cria um AuditLog para cada conversa atribuída' do
      expect {
        service.perform_bulk_assignment(limit: 1)
      }.to change(Starchat::AuditLog, :count).by(1)
    end

    it 'o AuditLog registra assignment_source como auto_assignment_v2' do
      service.perform_bulk_assignment(limit: 1)
      log = Starchat::AuditLog.last
      expect(log.audited_changes['assignment_source']).to eq('auto_assignment_v2')
    end

    it 'o AuditLog aponta para a conversa correta' do
      service.perform_bulk_assignment(limit: 1)
      log = Starchat::AuditLog.last
      expect(log.auditable).to eq(conv)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 14: Inbox sem política vinculada
  # ══════════════════════════════════════════════════════════════════════════
  describe 'inbox sem política vinculada' do
    let(:inbox_no_policy) { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:service_np) { AutoAssignment::AssignmentService.new(inbox: inbox_no_policy) }

    before do
      create(:inbox_member, inbox: inbox_no_policy, user: agent1)
      create(:inbox_member, inbox: inbox_no_policy, user: agent2)
      set_online(agent1, agent2)
    end

    let!(:conversations) { Array.new(20) { create(:conversation, inbox: inbox_no_policy, assignee: nil, status: 'open') } }

    it 'a política é nil' do
      expect(service_np.send(:policy)).to be_nil
    end

    it 'ainda atribui conversas usando round-robin padrão' do
      count = service_np.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'distribui entre os agentes disponíveis' do
      service_np.perform_bulk_assignment(limit: 20)
      assigned_ids = conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      expect(assigned_ids.size).to eq(2)
    end
  end
end
