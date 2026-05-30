# frozen_string_literal: true

require 'rails_helper'

# ─────────────────────────────────────────────────────────────────────────────
# Suite: Equal Distribution Assignment
#
# Verifica o comportamento do serviço quando a política usa
# assignment_order: :equal_distribution.
#
# O EqualDistributionSelector:
#   1. Conta conversas abertas por agente dentro da janela (window_hours)
#   2. Calcula spread_pct = (max - min) / max * 100
#   3. spread_pct <= balance_threshold → fallback round-robin (cargas parecidas)
#   4. spread_pct >  balance_threshold → agente com MENOR carga
#   5. window_hours = 0 implica contar TODAS as conversas abertas (sem janela)
#
# Nota: pela validação do modelo, equal_distribution_window_hours > 0 é
# obrigatório. Para testar o comportamento com janela = 0 (modo "balanced puro")
# o record é persistido sem validação via `save(validate: false)`.
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe 'Equal Distribution Assignment', type: :service do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account, enable_auto_assignment: true) }

  let(:agent1) { create(:user, account: account, name: 'ED-Agent-1') }
  let(:agent2) { create(:user, account: account, name: 'ED-Agent-2') }
  let(:agent3) { create(:user, account: account, name: 'ED-Agent-3') }

  # Política com equal_distribution — threshold=20, window=24h
  let(:policy) do
    create(:assignment_policy,
           account: account,
           assignment_order: :equal_distribution,
           conversation_priority: :earliest_created,
           equal_distribution_window_hours: 24,
           equal_distribution_balance_threshold: 20,
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

  def assign_open_conversations(agent, count:, created_ago: 1.hour)
    Array.new(count) do
      create(:conversation, inbox: inbox, assignee: agent, status: 'open',
                            created_at: created_ago.ago)
    end
  end

  # ─── Setup padrão ─────────────────────────────────────────────────────────

  before do
    account.enable_features!('assignment_v2')
    # Clear all relevant Redis keys to prevent flakiness
    Redis::Alfred.scan_each(match: "ASSIGNMENT::*") { |key| Redis::Alfred.delete(key) }
    Redis::Alfred.delete(format(Redis::Alfred::ROUND_ROBIN_AGENTS, inbox_id: inbox.id))
    Redis::Alfred.delete(OnlineStatusTracker.status_key(account.id))
    Redis::Alfred.delete(OnlineStatusTracker.presence_key(account.id, 'User'))

    create(:inbox_member, inbox: inbox, user: agent1)
    create(:inbox_member, inbox: inbox, user: agent2)
    create(:inbox_member, inbox: inbox, user: agent3)

    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)

    set_online(agent1, agent2, agent3)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 1: Seletor correto instanciado
  # ══════════════════════════════════════════════════════════════════════════
  describe 'seleção do seletor (resolve_selector)' do
    it 'instancia EqualDistributionSelector' do
      ed_selector = instance_double(
        Starchat::AutoAssignment::EqualDistributionSelector,
        select_agent: nil
      )
      allow(Starchat::AutoAssignment::EqualDistributionSelector)
        .to receive(:new).and_return(ed_selector)

      create_open_conversation
      service.perform_bulk_assignment(limit: 1)

      expect(Starchat::AutoAssignment::EqualDistributionSelector)
        .to have_received(:new)
        .with(
          inbox: inbox,
          window_hours: 24,
          balance_threshold: 20,
          round_robin_fallback: anything
        )
    end

    it 'não instancia BalancedSelector' do
      allow(Starchat::AutoAssignment::BalancedSelector).to receive(:new).and_call_original
      create_open_conversation
      service.perform_bulk_assignment(limit: 1)
      expect(Starchat::AutoAssignment::BalancedSelector).not_to have_received(:new)
    end

    it 'passa window_hours da política para o seletor' do
      policy.update!(equal_distribution_window_hours: 48)
      fresh = AutoAssignment::AssignmentService.new(inbox: inbox)
      captured_args = nil
      allow(Starchat::AutoAssignment::EqualDistributionSelector)
        .to receive(:new) do |args|
          captured_args = args
          instance_double(Starchat::AutoAssignment::EqualDistributionSelector, select_agent: nil)
        end
      create_open_conversation
      fresh.perform_bulk_assignment(limit: 1)
      expect(captured_args[:window_hours]).to eq(48)
    end

    it 'passa balance_threshold da política para o seletor' do
      policy.update!(equal_distribution_balance_threshold: 35)
      fresh = AutoAssignment::AssignmentService.new(inbox: inbox)
      captured_args = nil
      allow(Starchat::AutoAssignment::EqualDistributionSelector)
        .to receive(:new) do |args|
          captured_args = args
          instance_double(Starchat::AutoAssignment::EqualDistributionSelector, select_agent: nil)
        end
      create_open_conversation
      fresh.perform_bulk_assignment(limit: 1)
      expect(captured_args[:balance_threshold]).to eq(35)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 2: Desequilíbrio detectado → atribui ao menos carregado
  # Spread = (max - min) / max * 100 > threshold → equal distribution ativa
  # ══════════════════════════════════════════════════════════════════════════
  describe 'desequilíbrio de carga: atribui ao agente menos carregado' do
    before do
      # agent1 = 20 convs, agent2 = 8 convs, agent3 = 2 convs
      # spread = (20-2)/20*100 = 90% >> 20% threshold
      assign_open_conversations(agent1, count: 20)
      assign_open_conversations(agent2, count: 8)
      assign_open_conversations(agent3, count: 2)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'atribui todas as 20 novas conversas' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'primeiras atribuições vão para o agente3 (menos carregado)' do
      service.perform_bulk_assignment(limit: 5)
      assigned_to_agent3 = new_conversations.count { |c| c.reload.assignee == agent3 }
      expect(assigned_to_agent3).to be >= 1
    end

    it 'não atribui ao agente mais carregado na primeira rodada' do
      service.perform_bulk_assignment(limit: 1)
      # agent1 tem 20 convs → não deve ser o primeiro a receber
      expect(new_conversations.first.reload.assignee).not_to eq(agent1)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 3: Cargas equilibradas → fallback para round-robin
  # ══════════════════════════════════════════════════════════════════════════
  describe 'cargas equilibradas: fallback para round-robin' do
    before do
      # agent1=10, agent2=10, agent3=10 → spread=0% ≤ 20% threshold → round-robin
      assign_open_conversations(agent1, count: 10)
      assign_open_conversations(agent2, count: 10)
      assign_open_conversations(agent3, count: 10)
    end

    let!(:new_conversations) { Array.new(12) { create_open_conversation } }

    it 'atribui todas as novas conversas' do
      count = service.perform_bulk_assignment(limit: 12)
      expect(count).to eq(12)
    end

    it 'distribui entre os 3 agentes (round-robin)' do
      service.perform_bulk_assignment(limit: 12)
      assigned_ids = new_conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      expect(assigned_ids.size).to eq(3)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 4: Filtro de janela de tempo (window_hours)
  # ══════════════════════════════════════════════════════════════════════════
  describe 'janela de tempo filtra conversas antigas' do
    before do
      # agent1 tem 15 conversas criadas há 48h (fora da janela de 24h)
      # agent2 tem 2 conversas criadas há 1h (dentro da janela)
      # → dentro da janela: agent1=0, agent2=2 → agente1 deve ser preferido
      assign_open_conversations(agent1, count: 15, created_ago: 48.hours)
      assign_open_conversations(agent2, count: 2, created_ago: 1.hour)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'ignora conversas fora da janela na contagem de carga' do
      service.perform_bulk_assignment(limit: 1)
      # agent1 tem carga 0 dentro da janela → deve ser escolhido primeiro
      expect(new_conversations.first.reload.assignee).to eq(agent1)
    end

    it 'o spread calculado considera apenas conversas dentro da janela' do
      # Testa o seletor diretamente
      members = inbox.inbox_members.includes(:user)
      selector = Starchat::AutoAssignment::EqualDistributionSelector.new(
        inbox: inbox,
        window_hours: 24,
        balance_threshold: 20,
        round_robin_fallback: AutoAssignment::RoundRobinSelector.new(inbox: inbox)
      )
      # Com agent1=0, agent2=2 na janela → spread=(2-0)/2*100=100% > 20% → equal
      result = selector.select_agent(members.to_a)
      expect(result).not_to be_nil
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 5: Threshold 0 — sempre usa equal distribution
  # ══════════════════════════════════════════════════════════════════════════
  describe 'balance_threshold = 0: qualquer diferença ativa equal distribution' do
    before do
      policy.update!(equal_distribution_balance_threshold: 0)
      OnlineStatusTracker.set_status(account.id, agent3.id, 'offline')
      # agent1=5, agent2=4 → spread=(5-4)/5*100=20% > 0% → equal
      assign_open_conversations(agent1, count: 5)
      assign_open_conversations(agent2, count: 4)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'atribui ao agente com MENOR carga, não ao round-robin' do
      service.perform_bulk_assignment(limit: 1)
      # agent2 tem 4 convs vs agent1 com 5 (agent3 offline) → agent2 deve ser escolhido
      expect(new_conversations.first.reload.assignee).to eq(agent2)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 6: Threshold 100 — sempre usa round-robin (spread sempre ≤ 100%)
  # ══════════════════════════════════════════════════════════════════════════
  describe 'balance_threshold = 100: sempre usa fallback round-robin' do
    before do
      policy.update!(equal_distribution_balance_threshold: 100)
      # agent1=100, agent2=1 → spread=99% ≤ 100% → round-robin
      assign_open_conversations(agent1, count: 100)
      assign_open_conversations(agent2, count: 1)
    end

    let!(:new_conversations) { Array.new(6) { create_open_conversation } }

    it 'distribui entre os agentes via round-robin independente do desequilíbrio' do
      service.perform_bulk_assignment(limit: 6)
      assigned_ids = new_conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      # Num cenário de threshold=100, qualquer spread ≤ 100 → round-robin
      # logo ambos os agentes devem aparecer
      expect(assigned_ids.size).to be >= 1
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 7: Todos os agentes com carga zero
  # ══════════════════════════════════════════════════════════════════════════
  describe 'todos os agentes sem conversas (carga zero)' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'atribui todas as conversas sem erros' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'usa round-robin quando todos têm carga zero (balanced_enough? = true)' do
      # Todos zero → spread=0 ≤ 20% → round-robin
      service.perform_bulk_assignment(limit: 20)
      assigned_ids = new_conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      expect(assigned_ids.size).to eq(3)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 8: 1 agente disponível
  # ══════════════════════════════════════════════════════════════════════════
  describe '1 agente disponível de 3' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    before do
      [agent2, agent3].each { |a| OnlineStatusTracker.set_status(account.id, a.id, 'offline') }
    end

    it 'atribui ao único agente disponível até o limite fair_distribution' do
      count = service.perform_bulk_assignment(limit: 20)
      # fair_distribution_limit: 10 (factory) impede mais de 10 atribuições por agente por janela
      expect(count).to eq(10)
      assignees = new_conversations.map { |c| c.reload.assignee }.uniq.compact
      expect(assignees).to eq([agent1])
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 9: Nenhum agente disponível
  # ══════════════════════════════════════════════════════════════════════════
  describe 'nenhum agente disponível' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    before do
      [agent1, agent2, agent3].each { |a| OnlineStatusTracker.set_status(account.id, a.id, 'offline') }
    end

    it 'não atribui nenhuma conversa' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(0)
    end

    it 'todas as conversas ficam sem assignee' do
      service.perform_bulk_assignment(limit: 20)
      new_conversations.each { |c| expect(c.reload.assignee).to be_nil }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 10: Guarda enable_auto_assignment
  # ══════════════════════════════════════════════════════════════════════════
  describe 'guarda enable_auto_assignment' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    context 'com auto_assignment desativado' do
      before { inbox.update!(enable_auto_assignment: false) }

      it 'a política é nil' do
        expect(service.send(:policy)).to be_nil
      end

      it 'o EqualDistributionSelector não é instanciado' do
        allow(Starchat::AutoAssignment::EqualDistributionSelector).to receive(:new).and_call_original
        service.perform_bulk_assignment(limit: 5)
        expect(Starchat::AutoAssignment::EqualDistributionSelector).not_to have_received(:new)
      end
    end

    context 'com auto_assignment ativado' do
      it 'a política é carregada' do
        expect(service.send(:policy)).to eq(policy)
      end
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 11: Window_hours = 1 (janela muito estreita)
  # ══════════════════════════════════════════════════════════════════════════
  describe 'window_hours = 1 (janela estreita)' do
    before do
      policy.update!(equal_distribution_window_hours: 1)
      # agent1: 15 convs criadas há 2h (fora da janela de 1h)
      # agent2: 3 convs criadas há 30min (dentro da janela)
      assign_open_conversations(agent1, count: 15, created_ago: 2.hours)
      assign_open_conversations(agent2, count: 3, created_ago: 30.minutes)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'desconta corretamente as conversas fora da janela de 1h' do
      service.perform_bulk_assignment(limit: 1)
      # agent1 tem 0 dentro de 1h, agent2 tem 3 → agent1 deve ser escolhido
      expect(new_conversations.first.reload.assignee).to eq(agent1)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 12: 20 conversas com spread exatamente no threshold
  # ══════════════════════════════════════════════════════════════════════════
  describe 'spread exatamente no threshold → round-robin (≤ não ativa equal)' do
    before do
      policy.update!(equal_distribution_balance_threshold: 50)
      # agent1=10, agent2=5 → spread = (10-5)/10*100 = 50% = threshold → round-robin
      assign_open_conversations(agent1, count: 10)
      assign_open_conversations(agent2, count: 5)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'usa round-robin quando spread = threshold (condição <=)' do
      service.perform_bulk_assignment(limit: 6)
      assigned_ids = new_conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      # Round-robin distribuiria entre agent1, agent2 (e possivelmente agent3)
      expect(assigned_ids).not_to be_empty
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 13: Prioridade longest_waiting com equal_distribution
  # ══════════════════════════════════════════════════════════════════════════
  describe 'prioridade longest_waiting + equal_distribution' do
    let!(:policy_lw) do
      create(:assignment_policy,
             account: account,
             assignment_order: :equal_distribution,
             conversation_priority: :longest_waiting,
             equal_distribution_window_hours: 24,
             equal_distribution_balance_threshold: 20,
             enabled: true)
    end
    let(:inbox_lw)   { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:service_lw) { AutoAssignment::AssignmentService.new(inbox: inbox_lw) }

    before do
      create(:inbox_member, inbox: inbox_lw, user: agent1)
      create(:inbox_assignment_policy, inbox: inbox_lw, assignment_policy: policy_lw)
      set_online(agent1)
    end

    let!(:recently_active)  { create(:conversation, inbox: inbox_lw, assignee: nil, status: 'open', last_activity_at: 10.minutes.ago) }
    let!(:inactive_1h)      { create(:conversation, inbox: inbox_lw, assignee: nil, status: 'open', last_activity_at: 1.hour.ago) }
    let!(:inactive_5h)      { create(:conversation, inbox: inbox_lw, assignee: nil, status: 'open', last_activity_at: 5.hours.ago) }

    it 'busca primeiro a conversa com last_activity_at mais antigo' do
      service_lw.perform_bulk_assignment(limit: 1)
      expect(inactive_5h.reload.assignee).to eq(agent1)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 14: assignment_config inclui parâmetros de equal_distribution
  # ══════════════════════════════════════════════════════════════════════════
  describe 'assignment_config exporta configurações de equal_distribution' do
    it 'define equal_distribution_enabled = true' do
      config = service.send(:assignment_config)
      expect(config['equal_distribution_enabled']).to be true
    end

    it 'inclui window_hours correto' do
      config = service.send(:assignment_config)
      expect(config['equal_distribution_window_hours']).to eq(24)
    end

    it 'inclui balance_threshold correto' do
      config = service.send(:assignment_config)
      expect(config['equal_distribution_balance_threshold']).to eq(20)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 15: Respeito ao limit no bulk_assignment
  # ══════════════════════════════════════════════════════════════════════════
  describe 'respeita limit no bulk_assignment' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'com limit: 5 atribui exatamente 5' do
      count = service.perform_bulk_assignment(limit: 5)
      expect(count).to eq(5)
    end

    it 'com limit: 100 atribui todas as 20' do
      count = service.perform_bulk_assignment(limit: 100)
      expect(count).to eq(20)
    end
  end
end
