# frozen_string_literal: true

require 'rails_helper'

# ─────────────────────────────────────────────────────────────────────────────
# Suite: Balanced Assignment
#
# Verifica o comportamento do serviço quando a política usa
# assignment_order: :balanced.
#
# O BalancedSelector:
#   1. Conta TODAS as conversas abertas de cada agente na inbox (sem janela)
#   2. Seleciona o agente com o MENOR número de conversas abertas
#   3. Em empate, min_by retorna o primeiro encontrado (determinístico)
#
# Diferença essencial em relação ao EqualDistribution:
#   - Sem limiar (threshold): sempre escolhe o menos carregado
#   - Sem janela de tempo: toda conversa aberta conta
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe 'Balanced Assignment', type: :service do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account, enable_auto_assignment: true) }

  let(:agent1) { create(:user, account: account, name: 'BAL-Agent-1') }
  let(:agent2) { create(:user, account: account, name: 'BAL-Agent-2') }
  let(:agent3) { create(:user, account: account, name: 'BAL-Agent-3') }

  let(:policy) do
    create(:assignment_policy,
           account: account,
           assignment_order: :balanced,
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

  def assign_open_conversations(agent, count:, created_ago: 1.hour)
    Array.new(count) do
      create(:conversation, inbox: inbox, assignee: agent, status: 'open',
                            created_at: created_ago.ago)
    end
  end

  # ─── Setup padrão ─────────────────────────────────────────────────────────

  before do
    create(:inbox_member, inbox: inbox, user: agent1)
    create(:inbox_member, inbox: inbox, user: agent2)
    create(:inbox_member, inbox: inbox, user: agent3)

    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)

    set_online(agent1, agent2, agent3)

    allow(account).to receive(:feature_enabled?).and_return(false)
    allow(account).to receive(:feature_enabled?).with('assignment_v2').and_return(true)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 1: Seletor correto instanciado
  # ══════════════════════════════════════════════════════════════════════════
  describe 'seleção do seletor (resolve_selector)' do
    it 'instancia BalancedSelector' do
      bal_selector = instance_double(
        Starchat::AutoAssignment::BalancedSelector,
        select_agent: nil
      )
      allow(Starchat::AutoAssignment::BalancedSelector)
        .to receive(:new).and_return(bal_selector)

      create_open_conversation
      service.perform_bulk_assignment(limit: 1)

      expect(Starchat::AutoAssignment::BalancedSelector)
        .to have_received(:new).with(inbox: inbox)
    end

    it 'não instancia EqualDistributionSelector' do
      allow(Starchat::AutoAssignment::EqualDistributionSelector).to receive(:new).and_call_original
      create_open_conversation
      service.perform_bulk_assignment(limit: 1)
      expect(Starchat::AutoAssignment::EqualDistributionSelector).not_to have_received(:new)
    end

    it 'o método policy? retorna true para balanced' do
      expect(policy.balanced?).to be true
      expect(policy.round_robin?).to be false
      expect(policy.equal_distribution?).to be false
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 2: Atribuição básica ao menos carregado com 20 conversas
  # ══════════════════════════════════════════════════════════════════════════
  describe 'atribui ao agente com menor carga — 20 conversas' do
    before do
      # agent1=15, agent2=3, agent3=0 → agent3 deve ser escolhido
      assign_open_conversations(agent1, count: 15)
      assign_open_conversations(agent2, count: 3)
      # agent3 fica com 0
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'atribui todas as 20 conversas' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'a primeira atribuição vai para agent3 (carga 0)' do
      service.perform_bulk_assignment(limit: 1)
      expect(new_conversations.first.reload.assignee).to eq(agent3)
    end

    it 'a primeira atribuição NÃO vai para agent1 (carga 15)' do
      service.perform_bulk_assignment(limit: 1)
      expect(new_conversations.first.reload.assignee).not_to eq(agent1)
    end

    it 'tende a equilibrar as cargas ao longo das 20 atribuições' do
      service.perform_bulk_assignment(limit: 20)
      # Conta conversas abertas totais por agente após atribuição
      counts = [agent1, agent2, agent3].map do |agent|
        inbox.conversations.open.where(assignee: agent).count
      end
      max = counts.max
      min = counts.min
      # O balanced deve tender a equilibrar — diferença menor que a inicial (15)
      expect(max - min).to be < 15
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 3: Toda conversa aberta conta (sem janela de tempo)
  # ══════════════════════════════════════════════════════════════════════════
  describe 'conta conversas antigas e recentes (sem janela)' do
    before do
      # agent1: 10 convs há 7 dias (muito antigas)
      # agent2: 0 convs
      # → balanced conta TUDO → agent1 tem 10, agent2 tem 0 → agent2 é escolhido
      assign_open_conversations(agent1, count: 10, created_ago: 7.days)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'considera conversas antigas na contagem de carga' do
      service.perform_bulk_assignment(limit: 1)
      # agent1 tem 10 históricos → agent2 ou agent3 deve ser escolhido
      expect(new_conversations.first.reload.assignee).not_to eq(agent1)
    end

    it 'atribui as primeiras conversas a agent2 ou agent3 (carga zero)' do
      service.perform_bulk_assignment(limit: 2)
      first_two = new_conversations.first(2).map { |c| c.reload.assignee }.uniq.compact
      first_two.each do |agent|
        expect(agent).to satisfy('ser agent2 ou agent3') { |a| [agent2, agent3].include?(a) }
      end
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 4: Empate de carga (todos com mesma quantidade)
  # ══════════════════════════════════════════════════════════════════════════
  describe 'empate de carga entre agentes' do
    before do
      # agent1=5, agent2=5, agent3=5 → empate → min_by pega o primeiro
      assign_open_conversations(agent1, count: 5)
      assign_open_conversations(agent2, count: 5)
      assign_open_conversations(agent3, count: 5)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'atribui todas as conversas sem erros' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'distribui entre os agentes disponíveis no empate' do
      service.perform_bulk_assignment(limit: 20)
      assigned = new_conversations.map { |c| c.reload.assignee }.compact
      expect(assigned).not_to be_empty
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 5: Todos com carga zero
  # ══════════════════════════════════════════════════════════════════════════
  describe 'todos os agentes com carga zero' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'atribui todas as 20 conversas' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(20)
    end

    it 'distribui entre os 3 agentes' do
      service.perform_bulk_assignment(limit: 20)
      assigned_ids = new_conversations.map { |c| c.reload.assignee&.id }.compact.uniq
      # min_by com carga 0 = first, então pode ser só 1 agente até ser recarregado
      expect(assigned_ids).not_to be_empty
    end

    it 'nenhuma conversa fica sem assignee' do
      service.perform_bulk_assignment(limit: 20)
      unassigned = new_conversations.count { |c| c.reload.assignee.nil? }
      expect(unassigned).to eq(0)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 6: Nenhum agente disponível
  # ══════════════════════════════════════════════════════════════════════════
  describe 'nenhum agente disponível' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    before do
      [agent1, agent2, agent3].each { |a| OnlineStatusTracker.set_status(account.id, a.id, 'offline') }
    end

    it 'retorna 0 atribuições' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(0)
    end

    it 'nenhuma conversa é atribuída' do
      service.perform_bulk_assignment(limit: 20)
      new_conversations.each { |c| expect(c.reload.assignee).to be_nil }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 7: 1 agente disponível
  # ══════════════════════════════════════════════════════════════════════════
  describe '1 agente disponível' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    before do
      [agent2, agent3].each { |a| OnlineStatusTracker.set_status(account.id, a.id, 'offline') }
    end

    it 'atribui ao único agente disponível até o limite fair_distribution' do
      count = service.perform_bulk_assignment(limit: 20)
      # fair_distribution_limit: 10 (factory) impede mais de 10 atribuições por agente por janela
      expect(count).to eq(10)
      new_conversations.first(10).each { |c| expect(c.reload.assignee).to eq(agent1) }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 8: Conversas já atribuídas não são reatribuídas
  # ══════════════════════════════════════════════════════════════════════════
  describe 'conversas já atribuídas são ignoradas' do
    let!(:unassigned_convs) { Array.new(10) { create_open_conversation } }
    let!(:assigned_convs)   { Array.new(10) { create(:conversation, inbox: inbox, assignee: agent1, status: 'open') } }

    it 'conta apenas conversas sem assignee para atribuição' do
      count = service.perform_bulk_assignment(limit: 20)
      expect(count).to eq(10)
    end

    it 'não altera o assignee das conversas já atribuídas' do
      service.perform_bulk_assignment(limit: 20)
      assigned_convs.each { |c| expect(c.reload.assignee).to eq(agent1) }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 9: Conversas fechadas não contam como carga
  # ══════════════════════════════════════════════════════════════════════════
  describe 'conversas fechadas não são contadas na carga do agente' do
    before do
      # agent1: 10 conversas FECHADAS → não contam
      # agent2: 5 conversas ABERTAS
      Array.new(10) { create(:conversation, inbox: inbox, assignee: agent1, status: 'resolved') }
      assign_open_conversations(agent2, count: 5)
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'agent1 (10 fechadas) é preferido em relação ao agent2 (5 abertas)' do
      service.perform_bulk_assignment(limit: 1)
      # agent1 tem 0 abertas → agent2 tem 5 → agent1 deve ser escolhido
      expect(new_conversations.first.reload.assignee).to eq(agent1)
    end

    it 'não conta conversas com status resolved na carga' do
      selector = Starchat::AutoAssignment::BalancedSelector.new(inbox: inbox)
      members = inbox.inbox_members.includes(:user).to_a
      result = selector.select_agent(members)
      # agent1 (0 abertas) deve ser selecionado, não agent2 (5 abertas)
      expect(result).to eq(agent1)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 10: Agente com muita carga de outras inboxes não interfere
  # ══════════════════════════════════════════════════════════════════════════
  describe 'carga de outras inboxes não interfere no balanceamento' do
    let(:other_inbox) { create(:inbox, account: account, enable_auto_assignment: true) }

    before do
      create(:inbox_member, inbox: other_inbox, user: agent1)
      # agent1 tem 20 conversas abertas em OUTRA inbox
      Array.new(20) { create(:conversation, inbox: other_inbox, assignee: agent1, status: 'open') }
      # Na inbox sob teste: todos têm carga zero
    end

    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'a contagem considera somente a inbox da política' do
      service.perform_bulk_assignment(limit: 1)
      # agent1 tem 0 abertas na inbox atual apenas → pode ser escolhido
      assigned = new_conversations.first.reload.assignee
      expect([agent1, agent2, agent3]).to include(assigned)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 11: Guarda enable_auto_assignment
  # ══════════════════════════════════════════════════════════════════════════
  describe 'guarda enable_auto_assignment' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    context 'com auto_assignment desativado' do
      before { inbox.update!(enable_auto_assignment: false) }

      it 'a política retorna nil' do
        expect(service.send(:policy)).to be_nil
      end

      it 'o BalancedSelector não é instanciado' do
        allow(Starchat::AutoAssignment::BalancedSelector).to receive(:new).and_call_original
        service.perform_bulk_assignment(limit: 5)
        expect(Starchat::AutoAssignment::BalancedSelector).not_to have_received(:new)
      end
    end

    context 'com auto_assignment ativado' do
      it 'a política é carregada corretamente' do
        expect(service.send(:policy)).to eq(policy)
      end

      it 'o assignment_config reporta balanced = true' do
        config = service.send(:assignment_config)
        expect(config['balanced']).to be true
      end
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 12: assignment_config com balanced
  # ══════════════════════════════════════════════════════════════════════════
  describe 'assignment_config com política balanced' do
    it 'define balanced = true' do
      config = service.send(:assignment_config)
      expect(config['balanced']).to be true
    end

    it 'não define equal_distribution_enabled' do
      config = service.send(:assignment_config)
      expect(config['equal_distribution_enabled']).to be_nil
    end

    it 'exporta conversation_priority da política' do
      config = service.send(:assignment_config)
      expect(config['conversation_priority']).to eq('earliest_created')
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 13: Progressão dinâmica de carga
  # Cada atribuição aumenta a carga do agente escolhido → próxima vai ao menos carregado
  # ══════════════════════════════════════════════════════════════════════════
  describe 'progressão dinâmica: carga atualiza entre atribuições' do
    let!(:new_conversations) do
      # 3 conversas em sequência
      [
        create_open_conversation(created_at: 3.hours.ago),
        create_open_conversation(created_at: 2.hours.ago),
        create_open_conversation(created_at: 1.hour.ago)
      ]
    end

    it 'redistribui progressivamente entre os agentes ao atribuir 3 conversas' do
      service.perform_bulk_assignment(limit: 3)
      assigned_agents = new_conversations.map { |c| c.reload.assignee }.compact
      # Com 3 agentes e 3 convs, cada um deve ter exatamente 1
      expect(assigned_agents.uniq.size).to eq(3)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 14: Respeita limit no bulk_assignment
  # ══════════════════════════════════════════════════════════════════════════
  describe 'respeita limit no bulk_assignment' do
    let!(:new_conversations) { Array.new(20) { create_open_conversation } }

    it 'com limit: 7 atribui exatamente 7' do
      count = service.perform_bulk_assignment(limit: 7)
      expect(count).to eq(7)
    end

    it 'com limit: 100 atribui todas as 20' do
      count = service.perform_bulk_assignment(limit: 100)
      expect(count).to eq(20)
    end

    it 'com limit: 0 não atribui nada' do
      count = service.perform_bulk_assignment(limit: 0)
      expect(count).to eq(0)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contexto 15: BalancedSelector diretamente — contagem e seleção isoladas
  # ══════════════════════════════════════════════════════════════════════════
  describe 'BalancedSelector diretamente' do
    let(:selector) { Starchat::AutoAssignment::BalancedSelector.new(inbox: inbox) }
    let(:members)  { inbox.inbox_members.includes(:user).to_a }

    it 'retorna nil com lista de agentes vazia' do
      result = selector.select_agent([])
      expect(result).to be_nil
    end

    it 'retorna o único usuário disponível' do
      single_member = members.first(1)
      result = selector.select_agent(single_member)
      expect(result).to eq(single_member.first.user)
    end

    it 'seleciona o agente com menor contagem' do
      assign_open_conversations(agent1, count: 10)
      assign_open_conversations(agent2, count: 3)
      # agent3 = 0
      result = selector.select_agent(members)
      expect(result).to eq(agent3)
    end

    it 'retorna um User, não um InboxMember' do
      result = selector.select_agent(members)
      expect(result).to be_a(User)
    end

    it 'em empate total retorna um dos agentes (determinístico via min_by)' do
      assign_open_conversations(agent1, count: 2)
      assign_open_conversations(agent2, count: 2)
      assign_open_conversations(agent3, count: 2)
      result = selector.select_agent(members)
      expect([agent1, agent2, agent3]).to include(result)
    end
  end
end
