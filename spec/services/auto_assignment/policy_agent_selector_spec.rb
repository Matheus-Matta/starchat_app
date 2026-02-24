# frozen_string_literal: true

require 'rails_helper'

# ─────────────────────────────────────────────────────────────────────────────
# Suite: AutoAssignment::PolicyAgentSelector
#
# Responsabilidade: dado um inbox + lista de IDs permitidos, selecionar o
# agente correto respeitando a política configurada na inbox
# (equal-distribution / balanced / round-robin).
#
# Cenários cobertos:
#   1.  Sem política → round-robin via Redis
#   2.  Política round_robin explícita → round-robin
#   3.  Política balanced → BalancedSelector (menor carga)
#   4.  Política equal_distribution (via AssignmentPolicy) → EqualDistributionSelector
#   5.  Política legacy equal_distribution (InboxAssignmentPolicy) → EqualDistributionSelector
#   6.  Todos os agentes offline → nil
#   7.  allowed_agent_ids vazio → nil
#   8.  Interseção allowed × online vazia → nil
#   9.  Retorna User (não InboxMember)
#   10. Respeita somente candidatos permitidos (ignora membros fora da lista)
#   11. Rotação circular: round-robin avança a fila corretamente
# ─────────────────────────────────────────────────────────────────────────────
RSpec.describe AutoAssignment::PolicyAgentSelector, type: :service do
  let!(:account) { create(:account) }
  let!(:inbox)   { create(:inbox, account: account, enable_auto_assignment: true) }

  # 3 membros da inbox
  let!(:agent1) { create(:user, account: account, auto_offline: false) }
  let!(:agent2) { create(:user, account: account, auto_offline: false) }
  let!(:agent3) { create(:user, account: account, auto_offline: false) }

  let!(:member1) { create(:inbox_member, inbox: inbox, user: agent1) }
  let!(:member2) { create(:inbox_member, inbox: inbox, user: agent2) }
  let!(:member3) { create(:inbox_member, inbox: inbox, user: agent3) }

  let(:allowed_ids) { [agent1.id, agent2.id, agent3.id] }

  # Coloca os 3 online por padrão
  before do
    [agent1, agent2, agent3].each do |agent|
      OnlineStatusTracker.update_presence(account.id, 'User', agent.id)
      OnlineStatusTracker.set_status(account.id, agent.id, 'online')
    end
  end

  def build_selector(ids = allowed_ids)
    described_class.new(inbox: inbox, allowed_agent_ids: ids)
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 1 & 2 — Sem política / policy round_robin → RoundRobinSelector
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando não há policy (round-robin padrão)' do
    it 'usa RoundRobinSelector' do
      expect_any_instance_of(AutoAssignment::RoundRobinSelector)
        .to receive(:select_agent).and_call_original

      result = build_selector.find_assignee
      expect(result).to be_a(User)
      expect(allowed_ids).to include(result.id)
    end

    it 'retorna diferentes agentes em chamadas consecutivas (rotação)' do
      first  = build_selector.find_assignee
      second = build_selector.find_assignee
      # Com 3 agentes online, a fila avança — não deve retornar sempre o mesmo
      expect([agent1, agent2, agent3]).to include(first)
      expect([agent1, agent2, agent3]).to include(second)
      expect(first).not_to eq(second)
    end
  end

  context 'quando policy tem assignment_order: round_robin' do
    let!(:policy) do
      create(:assignment_policy, account: account, assignment_order: :round_robin, enabled: true)
    end

    before { create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy) }

    it 'usa RoundRobinSelector' do
      expect_any_instance_of(AutoAssignment::RoundRobinSelector)
        .to receive(:select_agent).and_call_original

      build_selector.find_assignee
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 3 — Política balanced → BalancedSelector
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando policy tem assignment_order: balanced' do
    let!(:policy) do
      create(:assignment_policy, account: account, assignment_order: :balanced, enabled: true)
    end

    before { create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy) }

    it 'usa BalancedSelector' do
      expect_any_instance_of(Starchat::AutoAssignment::BalancedSelector)
        .to receive(:select_agent).and_call_original

      build_selector.find_assignee
    end

    it 'seleciona o agente com menor número de conversas abertas' do
      # agent1 tem 3 conversas, agent2 tem 1, agent3 tem 0
      create_list(:conversation, 3, inbox: inbox, assignee: agent1, account: account, status: :open)
      create(:conversation, inbox: inbox, assignee: agent2, account: account, status: :open)

      result = build_selector.find_assignee
      expect(result).to eq(agent3)
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 4 — Política equal_distribution (via AssignmentPolicy) → EqualDistributionSelector
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando policy tem assignment_order: equal_distribution' do
    let!(:policy) do
      create(:assignment_policy,
             account: account,
             assignment_order: :equal_distribution,
             equal_distribution_window_hours: 24,
             equal_distribution_balance_threshold: 20,
             enabled: true)
    end

    before { create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy) }

    it 'usa EqualDistributionSelector' do
      expect_any_instance_of(Starchat::AutoAssignment::EqualDistributionSelector)
        .to receive(:select_agent).and_call_original

      build_selector.find_assignee
    end

    it 'seleciona o agente com menor carga na janela quando spread > threshold' do
      # agent1=5, agent2=1, agent3=0 → spread alto → equal distribution ativo
      policy.update!(equal_distribution_balance_threshold: 0)
      create_list(:conversation, 5, inbox: inbox, assignee: agent1, account: account, status: :open)
      create(:conversation, inbox: inbox, assignee: agent2, account: account, status: :open)

      # Somente agent1 e agent2 são permitidos (exclui agent3 da lista)
      result = described_class.new(inbox: inbox, allowed_agent_ids: [agent1.id, agent2.id]).find_assignee
      expect(result).to eq(agent2)
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 5 — Política legacy equal_distribution (InboxAssignmentPolicy.equal_distribution_enabled)
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando inbox_assignment_policy tem equal_distribution_enabled=true (legado)' do
    let!(:policy) do
      create(:assignment_policy, account: account, assignment_order: :round_robin, enabled: true)
    end
    let!(:iap) do
      create(:inbox_assignment_policy,
             inbox: inbox,
             assignment_policy: policy,
             equal_distribution_enabled: true,
             equal_distribution_window_hours: 24,
             equal_distribution_balance_threshold: 20)
    end

    it 'usa EqualDistributionSelector' do
      expect_any_instance_of(Starchat::AutoAssignment::EqualDistributionSelector)
        .to receive(:select_agent).and_call_original

      build_selector.find_assignee
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 6 — Todos os agentes offline → nil
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando todos os agentes estão offline' do
    before do
      [agent1, agent2, agent3].each do |agent|
        OnlineStatusTracker.set_status(account.id, agent.id, 'offline')
      end
    end

    it 'retorna nil' do
      expect(build_selector.find_assignee).to be_nil
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 7 — allowed_agent_ids vazio → nil
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando allowed_agent_ids está vazio' do
    it 'retorna nil sem chamar nenhum seletor' do
      expect_any_instance_of(AutoAssignment::RoundRobinSelector).not_to receive(:select_agent)
      expect(build_selector([]).find_assignee).to be_nil
    end

    it 'também funciona com nil como entrada' do
      result = described_class.new(inbox: inbox, allowed_agent_ids: nil).find_assignee
      expect(result).to be_nil
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 8 — Interseção allowed × online é vazia → nil
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando agentes permitidos não estão online' do
    before { OnlineStatusTracker.set_status(account.id, agent1.id, 'offline') }

    it 'retorna nil quando o único agente permitido está offline' do
      result = described_class.new(inbox: inbox, allowed_agent_ids: [agent1.id]).find_assignee
      expect(result).to be_nil
    end

    it 'retorna agente online quando parte está offline' do
      OnlineStatusTracker.set_status(account.id, agent2.id, 'offline')
      # agent1 offline, agent2 offline, agent3 online
      result = described_class.new(inbox: inbox, allowed_agent_ids: [agent1.id, agent2.id, agent3.id]).find_assignee
      expect(result).to eq(agent3)
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 9 — Retorna User (não InboxMember)
  # ════════════════════════════════════════════════════════════════════════════
  it 'retorna uma instância de User' do
    result = build_selector.find_assignee
    expect(result).to be_a(User)
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 10 — Respeita somente candidatos permitidos
  # ════════════════════════════════════════════════════════════════════════════
  context 'quando allowed_agent_ids não inclui todos os membros da inbox' do
    it 'nunca seleciona um agente fora da lista permitida' do
      # Permite somente agent2
      20.times do
        result = described_class.new(inbox: inbox, allowed_agent_ids: [agent2.id]).find_assignee
        expect(result).to eq(agent2)
      end
    end

    it 'nunca seleciona um agente que não é membro da inbox' do
      outsider = create(:user, account: account, auto_offline: false)
      OnlineStatusTracker.update_presence(account.id, 'User', outsider.id)
      OnlineStatusTracker.set_status(account.id, outsider.id, 'online')

      # outsider está online mas NÃO é inbox_member
      result = described_class.new(inbox: inbox, allowed_agent_ids: [outsider.id]).find_assignee
      expect(result).to be_nil
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # 11 — Rotação round-robin avança a fila
  # ════════════════════════════════════════════════════════════════════════════
  context 'rotação circular de round-robin' do
    it 'distribui entre todos os agentes online com rotação circular' do
      assigned = Array.new(9) { build_selector.find_assignee }
      # Com 3 agentes e 9 chamadas, cada um deve aparecer 3 vezes
      [agent1, agent2, agent3].each do |agent|
        expect(assigned.count(agent)).to eq(3), "esperado 3 atribuições para #{agent.name}, mas got #{assigned.count(agent)}"
      end
    end

    it 'o próximo da fila é escolhido ao filtrar allowed_agent_ids a 2 dos 3' do
      # Permite só agent1 e agent2 → nunca agent3
      10.times do
        result = described_class.new(inbox: inbox, allowed_agent_ids: [agent1.id, agent2.id]).find_assignee
        expect(result).not_to eq(agent3)
      end
    end
  end
end
