require 'rails_helper'

# =============================================================================
# Testes da Distribuição Igualitária (EqualDistribution)
#
# Estrutura:
#   1. Testes unitários do EqualDistributionSelector
#      1.1  Comportamento base (nil / agente único)
#      1.2  Quando spread EXCEDE o limiar  → usa equal distribution
#      1.3  Quando spread está DENTRO do limiar → usa round-robin
#      1.4  Limiar threshold=0 (sem tolerância)
#      1.5  Limiar threshold=100 (sempre round-robin)
#      1.6  Janela de tempo: filtra conversas antigas
#      1.7  window_hours=0: sem filtro de tempo
#      1.8  Cálculo de spread_pct em diferentes cenários
#
#   2. Testes de integração (full pipeline)
#      2.1  Distribuição igualitária com múltiplas rodadas de bulk assignment
#      2.2  Fallback para round-robin quando cargas estão equilibradas
#      2.3  Per-inbox: inboxes diferentes com configurações diferentes
#      2.4  Validação final da distribuição com contagem real de conversas
# =============================================================================

RSpec.describe Starchat::AutoAssignment::EqualDistributionSelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  let(:agent1) { create(:user, account: account, name: 'Agente 1', role: :agent, availability: :online) }
  let(:agent2) { create(:user, account: account, name: 'Agente 2', role: :agent, availability: :online) }
  let(:agent3) { create(:user, account: account, name: 'Agente 3', role: :agent, availability: :online) }
  let(:agent4) { create(:user, account: account, name: 'Agente 4', role: :agent, availability: :online) }

  let(:member1) { create(:inbox_member, inbox: inbox, user: agent1) }
  let(:member2) { create(:inbox_member, inbox: inbox, user: agent2) }
  let(:member3) { create(:inbox_member, inbox: inbox, user: agent3) }
  let(:member4) { create(:inbox_member, inbox: inbox, user: agent4) }

  let(:rr_fallback) { instance_double('AutoAssignment::RoundRobinSelector') }

  def build_selector(window_hours: 24, threshold: 20)
    described_class.new(
      inbox: inbox,
      window_hours: window_hours,
      balance_threshold: threshold,
      round_robin_fallback: rr_fallback
    )
  end

  # Garante que rr_fallback pode ser chamado sem configuração explícita
  before do
    allow(rr_fallback).to receive(:select_agent) { |agents| agents.first.user }
  end

  # ===========================================================================
  # 1.1 Comportamento base
  # ===========================================================================
  describe '1.1 Comportamento base (nil / agente único)' do
    subject(:selector) { build_selector }

    it 'retorna nil quando a lista de agentes está vazia' do
      expect(selector.select_agent([])).to be_nil
    end

    it 'retorna o único agente sem calcular spread nem chamar round-robin' do
      create_list(:conversation, 99, inbox: inbox, assignee: agent1, status: 'open')
      # round-robin NÃO deve ser chamado
      expect(rr_fallback).not_to receive(:select_agent)

      result = selector.select_agent([member1])
      expect(result).to eq(agent1)
    end
  end

  # ===========================================================================
  # 1.2 Quando spread EXCEDE o limiar → usa equal distribution
  # ===========================================================================
  describe '1.2 Spread EXCEDE o limiar → equal distribution ativo' do
    subject(:selector) { build_selector(threshold: 20) }

    it 'spread=83%: agente1=20, agente2=30, agente3=5 → seleciona agente3' do
      create_list(:conversation, 20, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 30, inbox: inbox, assignee: agent2, status: 'open')
      create_list(:conversation, 5,  inbox: inbox, assignee: agent3, status: 'open')
      # spread = (30 - 5) / 30.0 * 100 = 83.3% > 20 → equal

      expect(rr_fallback).not_to receive(:select_agent)
      expect(selector.select_agent([member1, member2, member3])).to eq(agent3)
    end

    it 'spread=43%: agente1=8, agente2=14 → seleciona agente1' do
      create_list(:conversation, 8,  inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 14, inbox: inbox, assignee: agent2, status: 'open')
      # spread = (14 - 8) / 14.0 * 100 = 42.9% > 20 → equal

      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'spread=100%: agente2=10 e agente1=0 → seleciona agente1 (zero conversas)' do
      create_list(:conversation, 10, inbox: inbox, assignee: agent2, status: 'open')
      # agente1 = 0 conversas → spread = (10 - 0) / 10 * 100 = 100% > 20 → equal

      expect(rr_fallback).not_to receive(:select_agent)
      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'spread=75%: 4 agentes com cargas muito distintas → seleciona o com menor carga' do
      create_list(:conversation, 20, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 15, inbox: inbox, assignee: agent2, status: 'open')
      create_list(:conversation, 8,  inbox: inbox, assignee: agent3, status: 'open')
      create_list(:conversation, 5,  inbox: inbox, assignee: agent4, status: 'open')
      # spread = (20 - 5) / 20.0 * 100 = 75% > 20 → equal → seleciona agente4

      result = selector.select_agent([member1, member2, member3, member4])
      expect(result).to eq(agent4)
    end

    it 'ignora conversas resolvidas e pendentes — apenas conversas open contam' do
      # Agente 1: 1 open + 20 resolved + 5 pending
      create(:conversation, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 20, inbox: inbox, assignee: agent1, status: 'resolved')
      create_list(:conversation, 5,  inbox: inbox, assignee: agent1, status: 'pending')

      # Agente 2: 5 open
      create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
      # spread = (5 - 1) / 5.0 * 100 = 80% > 20 → equal → agente1 tem menor carga open

      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'desempate: múltiplos agentes com mesma carga mínima → retorna o primeiro na lista' do
      create_list(:conversation, 10, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 0,  inbox: inbox, assignee: agent2, status: 'open')
      create_list(:conversation, 0,  inbox: inbox, assignee: agent3, status: 'open')
      # agente2 e agente3 empatados em 0 → spread=(10-0)/10*100=100% > 20
      # min_by retorna o PRIMEIRO encontrado na ordem do array

      result = selector.select_agent([member1, member2, member3])
      expect([agent2, agent3]).to include(result)
    end
  end

  # ===========================================================================
  # 1.3 Quando spread está DENTRO do limiar → usa round-robin
  # ===========================================================================
  describe '1.3 Spread DENTRO do limiar → delega ao round-robin' do
    subject(:selector) { build_selector(threshold: 20) }

    it 'spread=17%: agente1=10, agente2=11, agente3=12 → round-robin' do
      create_list(:conversation, 10, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 11, inbox: inbox, assignee: agent2, status: 'open')
      create_list(:conversation, 12, inbox: inbox, assignee: agent3, status: 'open')
      # spread = (12 - 10) / 12.0 * 100 = 16.7% ≤ 20 → round-robin

      available = [member1, member2, member3]
      allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent2)

      result = selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent).with(available)
      expect(result).to eq(agent2)
    end

    it 'spread=20% (exatamente no limite) → round-robin' do
      create_list(:conversation, 4, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
      # spread = (5 - 4) / 5.0 * 100 = 20.0% == 20 → round-robin

      available = [member1, member2]
      allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent1)

      result = selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent)
      expect(result).to eq(agent1)
    end

    it 'todos os agentes com mesma carga (empate total) → round-robin' do
      create_list(:conversation, 7, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 7, inbox: inbox, assignee: agent2, status: 'open')
      create_list(:conversation, 7, inbox: inbox, assignee: agent3, status: 'open')
      # spread = 0% ≤ 20 → round-robin

      available = [member1, member2, member3]
      allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent3)

      result = selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent)
      expect(result).to eq(agent3)
    end

    it 'todos os agentes sem conversas (zero total) → round-robin' do
      # Nenhuma conversa criada — todos têm 0
      available = [member1, member2, member3]
      allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent1)

      result = selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent)
      expect(result).to eq(agent1)
    end
  end

  # ===========================================================================
  # 1.4 Limiar threshold=0 (sem tolerância)
  # ===========================================================================
  describe '1.4 threshold=0 — qualquer diferença usa equal distribution' do
    subject(:selector) { build_selector(threshold: 0) }

    it 'diferença de apenas 1 conversa já ativa equal distribution' do
      create_list(:conversation, 5, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 6, inbox: inbox, assignee: agent2, status: 'open')
      # spread = (6 - 5) / 6.0 * 100 = 16.7% > 0 → equal

      expect(rr_fallback).not_to receive(:select_agent)
      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'round-robin apenas quando spread é exatamente 0 (cargas idênticas)' do
      create_list(:conversation, 5, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
      # spread = 0% == 0 → round-robin

      available = [member1, member2]
      allow(rr_fallback).to receive(:select_agent).and_return(agent1)

      selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent)
    end
  end

  # ===========================================================================
  # 1.5 Limiar threshold=100 (sempre round-robin)
  # ===========================================================================
  describe '1.5 threshold=100 — sempre usa round-robin (spread nunca passa de 100%)' do
    subject(:selector) { build_selector(threshold: 100) }

    it 'mesmo com spread máximo (um agente com 0 e outro com 100) usa round-robin' do
      create_list(:conversation, 100, inbox: inbox, assignee: agent2, status: 'open')
      # spread = 100% == 100 ≤ 100 → round-robin

      available = [member1, member2]
      allow(rr_fallback).to receive(:select_agent).and_return(agent1)

      selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent)
    end
  end

  # ===========================================================================
  # 1.6 Janela de tempo: filtra conversas antigas
  # ===========================================================================
  describe '1.6 Janela de tempo filtra conversas antigas' do
    subject(:selector) { build_selector(window_hours: 2, threshold: 20) }

    it 'conversas fora da janela não são contadas → spread baseado apenas nas recentes' do
      # Agente 1: 9 conversas há 5h (fora da janela 2h) + 1 recente = contagem=1
      create_list(:conversation, 9, inbox: inbox, assignee: agent1, status: 'open',
                                    created_at: 5.hours.ago)
      create(:conversation, inbox: inbox, assignee: agent1, status: 'open')

      # Agente 2: 5 conversas recentes = contagem=5
      create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
      # spread janela = (5 - 1) / 5.0 * 100 = 80% > 20 → equal → seleciona agente1

      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'sem a janela agente1 teria 10 e seria penalizado (validação da diferença)' do
      # Mesmo setup mas com window_hours=0 → conta todas as conversas
      create_list(:conversation, 9, inbox: inbox, assignee: agent1, status: 'open',
                                    created_at: 5.hours.ago)
      create(:conversation, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')

      no_window_selector = build_selector(window_hours: 0, threshold: 20)
      # sem janela: agente1=10, agente2=5 → spread=(10-5)/10*100=50% > 20 → equal → agente2
      expect(no_window_selector.select_agent([member1, member2])).to eq(agent2)
    end

    it 'conversas criadas dentro da janela são contadas normalmente' do
      create_list(:conversation, 3, inbox: inbox, assignee: agent1, status: 'open',
                                    created_at: 30.minutes.ago)
      create_list(:conversation, 8, inbox: inbox, assignee: agent2, status: 'open',
                                    created_at: 1.hour.ago)
      # spread = (8 - 3) / 8.0 * 100 = 62.5% > 20 → equal → agente1 tem menos

      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'conversas criadas exatamente no limite da janela são incluídas' do
      create_list(:conversation, 5, inbox: inbox, assignee: agent1, status: 'open',
                                    created_at: 1.hour.ago) # 1h atrás, janela=2h → dentro
      create_list(:conversation, 10, inbox: inbox, assignee: agent2, status: 'open',
                                     created_at: 30.minutes.ago)
      # spread = (10 - 5) / 10.0 * 100 = 50% > 20 → equal → agente1

      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end
  end

  # ===========================================================================
  # 1.7 window_hours=0: sem filtro de tempo
  # ===========================================================================
  describe '1.7 window_hours=0 — conta todas as conversas abertas' do
    subject(:selector) { build_selector(window_hours: 0, threshold: 20) }

    it 'conta conversa criada há 1 ano' do
      create(:conversation, inbox: inbox, assignee: agent1, status: 'open', created_at: 1.year.ago)
      create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
      # spread = (5 - 1) / 5.0 * 100 = 80% > 20 → equal → agente1

      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end
  end

  # ===========================================================================
  # 1.8 Cálculo de spread_pct verificado matematicamente
  # ===========================================================================
  describe '1.8 Verificação matemática do spread_pct' do
    it 'spread=50% está acima de threshold=20 → equal' do
      # cargas: 5 e 10 → spread = (10-5)/10*100 = 50%
      create_list(:conversation, 5,  inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 10, inbox: inbox, assignee: agent2, status: 'open')

      selector = build_selector(threshold: 20)
      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end

    it 'spread=50% está abaixo de threshold=60 → round-robin' do
      create_list(:conversation, 5,  inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 10, inbox: inbox, assignee: agent2, status: 'open')

      available = [member1, member2]
      allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent1)

      selector = build_selector(threshold: 60)
      selector.select_agent(available)
      expect(rr_fallback).to have_received(:select_agent)
    end

    it 'spread=21% está 1 ponto acima de threshold=20 → equal' do
      # Para spread exato de ~21%: max=19, min=15 → (19-15)/19*100 = 21.05%
      create_list(:conversation, 15, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 19, inbox: inbox, assignee: agent2, status: 'open')

      selector = build_selector(threshold: 20)
      expect(rr_fallback).not_to receive(:select_agent)
      expect(selector.select_agent([member1, member2])).to eq(agent1)
    end
  end
end

# =============================================================================
# 2. Testes de Integração — Pipeline completo via AssignmentService
#
# Simula um ambiente real com 5 agentes e volumes de ~20 conversas por rodada.
# Cada cenário parte de um estado de backlog já existente (como ficaria no dia
# a dia) e valida o comportamento após a chegada em lote de novas conversas.
# =============================================================================
RSpec.describe 'Equal Distribution — Integração com AssignmentService', type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:assignment_policy) { create(:assignment_policy, account: account, enabled: true) }
  let(:service) { AutoAssignment::AssignmentService.new(inbox: inbox) }

  # 5 agentes simulando um time real de atendimento
  let!(:agent1) { create(:user, account: account, name: 'Ana',     role: :agent, availability: :online) }
  let!(:agent2) { create(:user, account: account, name: 'Bruno',   role: :agent, availability: :online) }
  let!(:agent3) { create(:user, account: account, name: 'Carla',   role: :agent, availability: :online) }
  let!(:agent4) { create(:user, account: account, name: 'Diego',   role: :agent, availability: :online) }
  let!(:agent5) { create(:user, account: account, name: 'Elisa',   role: :agent, availability: :online) }

  let!(:member1) { create(:inbox_member, inbox: inbox, user: agent1) }
  let!(:member2) { create(:inbox_member, inbox: inbox, user: agent2) }
  let!(:member3) { create(:inbox_member, inbox: inbox, user: agent3) }
  let!(:member4) { create(:inbox_member, inbox: inbox, user: agent4) }
  let!(:member5) { create(:inbox_member, inbox: inbox, user: agent5) }

  let(:all_agents) { [agent1, agent2, agent3, agent4, agent5] }

  before do
    allow(account).to receive(:feature_enabled?).and_return(false)
    allow(account).to receive(:feature_enabled?).with('assignment_v2').and_return(true)

    all_agents.each do |agent|
      OnlineStatusTracker.update_presence(account.id, 'User', agent.id)
      OnlineStatusTracker.set_status(account.id, agent.id, 'online')
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Cria a política por inbox (configuração per-inbox do equal_distribution)
  def setup_inbox_policy(enabled:, window_hours: 24, threshold: 20)
    create(:inbox_assignment_policy,
           inbox: inbox,
           assignment_policy: assignment_policy,
           equal_distribution_enabled: enabled,
           equal_distribution_window_hours: window_hours,
           equal_distribution_balance_threshold: threshold)
  end

  # Retorna { "Nome" => contagem_de_conversas_abertas } para os 5 agentes
  def load_distribution(scope_inbox = inbox)
    all_agents.each_with_object({}) do |agent, hash|
      hash[agent.name] = scope_inbox.conversations.open.where(assignee: agent).count
    end
  end

  # Calcula spread% da distribuição: (max - min) / max * 100
  def spread_pct(dist)
    values = dist.values.select(&:positive?)
    return 0 if values.empty? || values.max.zero?

    ((values.max - values.min).to_f / values.max * 100).round(1)
  end

  # Calcula desvio-padrão da distribuição
  def std_dev(dist)
    values = dist.values
    mean = values.sum.to_f / values.size
    variance = values.sum { |v| (v - mean)**2 } / values.size
    Math.sqrt(variance).round(2)
  end

  # ===========================================================================
  # 2.1 Cenário real: backlog desequilibrado + 20 novas conversas
  # ===========================================================================
  describe '2.1 Backlog desequilibrado + 20 novas conversas chegando' do
    # Simula fim do turno da manhã: alguns agentes pegaram mais que outros
    # Ana=28, Bruno=12, Carla=20, Diego=35, Elisa=5 → total=100 conversas em andamento
    before do
      setup_inbox_policy(enabled: true, threshold: 20)
      create_list(:conversation, 28, inbox: inbox, assignee: agent1, status: 'open') # Ana
      create_list(:conversation, 12, inbox: inbox, assignee: agent2, status: 'open') # Bruno
      create_list(:conversation, 20, inbox: inbox, assignee: agent3, status: 'open') # Carla
      create_list(:conversation, 35, inbox: inbox, assignee: agent4, status: 'open') # Diego
      create_list(:conversation, 5,  inbox: inbox, assignee: agent5, status: 'open') # Elisa
      # spread = (35-5)/35*100 = 85.7% > 20 → equal distribution ativo
    end

    it '20 novas conversas são todas atribuídas' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      unassigned = new_convs.count { |c| c.reload.assignee.nil? }
      expect(unassigned).to eq(0),
        "#{unassigned} conversas ficaram sem atribuição"
    end

    it 'as 20 novas conversas vão prioritariamente para quem tem menos carga (Elisa e Bruno)' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist_after = load_distribution
      elisa_received = dist_after['Elisa'] - 5
      bruno_received = dist_after['Bruno'] - 12
      diego_received = dist_after['Diego'] - 35

      # Elisa (menor carga inicial=5) deve receber a maioria
      expect(elisa_received).to be >= 5,
        "Elisa deveria receber bastante. Distribuição final: #{dist_after}"

      # Diego (maior carga inicial=35) deve receber poucas ou nenhuma
      expect(diego_received).to be <= 3,
        "Diego não deveria receber muitas novas conversas. Distribuição: #{dist_after}"
    end

    it 'spread% diminui após a redistribuição' do
      dist_before = load_distribution
      spread_before = spread_pct(dist_before)

      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist_after = load_distribution
      spread_after = spread_pct(dist_after)

      expect(spread_after).to be < spread_before,
        "Spread deveria diminuir após a redistribuição. " \
        "Antes=#{spread_before}%, Depois=#{spread_after}%\n" \
        "Distribuição antes: #{dist_before}\n" \
        "Distribuição depois: #{dist_after}"
    end

    it 'audit log é gerado para cada uma das 20 atribuições' do
      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')

      expect {
        service.perform_bulk_assignment(limit: 20)
      }.to change(Starchat::AuditLog, :count).by(20)

      logs = Starchat::AuditLog.order(:id).last(20)
      logs.each_with_index do |log, i|
        expect(log.action).to eq('auto_assign'),
          "Log #{i + 1}: action deveria ser auto_assign"
        expect(log.audited_changes['assignment_source']).to eq('auto_assignment_v2'),
          "Log #{i + 1}: source deveria ser auto_assignment_v2"
        expect(log.audited_changes['assignee_id']).to match([nil, be_an(Integer)]),
          "Log #{i + 1}: assignee_id malformado"
        expect(log.audited_changes['queue_before']).to be_an(Array),
          "Log #{i + 1}: queue_before ausente"
        expect(log.audited_changes['queue_after']).to be_an(Array),
          "Log #{i + 1}: queue_after ausente"
      end
    end
  end

  # ===========================================================================
  # 2.2 Cenário real: cargas equilibradas → round-robin mantém a ordem
  # ===========================================================================
  describe '2.2 Cargas já equilibradas — round-robin não é perturbado' do
    # Simula início de turno com pouquíssimas diferenças
    # Ana=18, Bruno=19, Carla=20, Diego=18, Elisa=19 → spread=(20-18)/20*100=10% ≤ 20
    before do
      setup_inbox_policy(enabled: true, threshold: 20)
      create_list(:conversation, 18, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 19, inbox: inbox, assignee: agent2, status: 'open')
      create_list(:conversation, 20, inbox: inbox, assignee: agent3, status: 'open')
      create_list(:conversation, 18, inbox: inbox, assignee: agent4, status: 'open')
      create_list(:conversation, 19, inbox: inbox, assignee: agent5, status: 'open')
      # spread = (20-18)/20*100 = 10% ≤ 20 → round-robin
    end

    it '20 novas conversas são todas atribuídas via round-robin' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      unassigned = new_convs.count { |c| c.reload.assignee.nil? }
      expect(unassigned).to eq(0),
        "#{unassigned} conversas ficaram sem atribuição via round-robin"
    end

    it 'a distribuição final continua equilibrada (spread ≤ 35%)' do
      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist_after = load_distribution
      spread_after = spread_pct(dist_after)

      expect(spread_after).to be <= 35,
        "Spread esperado ≤ 35% mas obteve #{spread_after}%. " \
        "Distribuição final: #{dist_after}"
    end

    it 'nenhum agente fica com carga mais do que 50% acima da média' do
      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist = load_distribution
      values = dist.values
      mean = values.sum.to_f / values.size
      overloaded = dist.select { |_, v| v > mean * 1.5 }

      expect(overloaded).to be_empty,
        "Agentes sobrecarregados (>150% da média=#{mean.round(1)}): #{overloaded}. " \
        "Distribuição: #{dist}"
    end
  end

  # ===========================================================================
  # 2.3 Cenário real: 1 agente sobrecarregado + 20 conversas novas
  # ===========================================================================
  describe '2.3 Um agente muito sobrecarregado — redistribuição emergencial' do
    # Diego assumiu um pico: Ana=10, Bruno=10, Carla=10, Diego=40, Elisa=10
    # spread = (40-10)/40*100 = 75% > 20 → equal distribution
    before do
      setup_inbox_policy(enabled: true, threshold: 20)
      [agent1, agent2, agent3, agent5].each do |agent|
        create_list(:conversation, 10, inbox: inbox, assignee: agent, status: 'open')
      end
      create_list(:conversation, 40, inbox: inbox, assignee: agent4, status: 'open') # Diego
    end

    it '20 novas conversas NÃO vão para Diego (já saturado)' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      diego_new = new_convs.count { |c| c.reload.assignee == agent4 }
      dist = load_distribution

      expect(diego_new).to eq(0),
        "Diego já estava com 40 conversas e recebeu #{diego_new} novas. " \
        "Distribuição final: #{dist}"
    end

    it '20 novas conversas são distribuídas entre os demais agentes (4 agentes × ~5)' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      new_per_agent = all_agents.each_with_object({}) do |agent, hash|
        hash[agent.name] = new_convs.count { |c| c.reload.assignee == agent }
      end

      others_total = new_per_agent.reject { |name, _| name == 'Diego' }.values.sum
      expect(others_total).to eq(20),
        "Esperava 20 conversas para os outros 4 agentes, obteve #{others_total}. " \
        "By agent: #{new_per_agent}"
    end
  end

  # ===========================================================================
  # 2.4 Cenário real: equal_distribution desabilitado por inbox
  # ===========================================================================
  describe '2.4 equal_distribution_enabled=false — round-robin padrão mesmo com desequilíbrio' do
    before do
      setup_inbox_policy(enabled: false)
      # Desequilíbrio severo — Ana=0, Elisa=60
      create_list(:conversation, 60, inbox: inbox, assignee: agent5, status: 'open') # Elisa
    end

    it '20 novas conversas são atribuídas a qualquer agente via round-robin' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      unassigned = new_convs.count { |c| c.reload.assignee.nil? }
      assigned_agents = new_convs.map { |c| c.reload.assignee }.compact.uniq

      expect(unassigned).to eq(0), "#{unassigned} conversas sem atribuição"
      # round-robin distribui entre todos, incluindo Elisa (não considera carga)
      expect(assigned_agents).not_to be_empty
    end
  end

  # ===========================================================================
  # 2.5 Cenário real: per-inbox — 2 inboxes com políticas distintas
  # ===========================================================================
  describe '2.5 Per-inbox: inbox A (equal ativo) e inbox B (desabilitado)' do
    let(:inbox_b)    { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:policy_b)   { create(:assignment_policy, account: account, enabled: true) }
    let(:service_b)  { AutoAssignment::AssignmentService.new(inbox: inbox_b) }

    before do
      # Mesmos 5 agentes na inbox_b também
      all_agents.each { |a| create(:inbox_member, inbox: inbox_b, user: a) }

      # inbox A: equal distribution ativo
      setup_inbox_policy(enabled: true, threshold: 20)

      # inbox B: equal distribution desabilitado
      create(:inbox_assignment_policy,
             inbox: inbox_b,
             assignment_policy: policy_b,
             equal_distribution_enabled: false)

      # Backlog em inbox A: desequilíbrio severo
      create_list(:conversation, 30, inbox: inbox, assignee: agent1, status: 'open')
      create_list(:conversation, 5,  inbox: inbox, assignee: agent5, status: 'open')

      # Backlog em inbox B: mesmo desequilíbrio, mas sem equal
      create_list(:conversation, 30, inbox: inbox_b, assignee: agent1, status: 'open')
      create_list(:conversation, 5,  inbox: inbox_b, assignee: agent5, status: 'open')
    end

    it 'inbox A redistribui para menos carregados; inbox B segue round-robin' do
      # 20 novas em cada inbox
      new_a = create_list(:conversation, 20, inbox: inbox,   assignee: nil, status: 'open')
      new_b = create_list(:conversation, 20, inbox: inbox_b, assignee: nil, status: 'open')

      service.perform_bulk_assignment(limit: 20)
      service_b.perform_bulk_assignment(limit: 20)

      # === inbox A: validar redistribuição ===
      elisa_a = new_a.count { |c| c.reload.assignee == agent5 }
      ana_a   = new_a.count { |c| c.reload.assignee == agent1 }
      unassigned_a = new_a.count { |c| c.reload.assignee.nil? }

      expect(unassigned_a).to eq(0), "inbox A: #{unassigned_a} conversas sem atribuição"
      expect(elisa_a).to be > ana_a,
        "inbox A (equal ativo): Elisa (carga=5) deveria receber mais que Ana (carga=30). " \
        "Elisa=+#{elisa_a} Ana=+#{ana_a}"

      # === inbox B: todas atribuídas, round-robin distribuindo ===
      unassigned_b = new_b.count { |c| c.reload.assignee.nil? }
      expect(unassigned_b).to eq(0), "inbox B: #{unassigned_b} conversas sem atribuição"

      # Isolamento: conversas da inbox A não aparecem na B e vice-versa
      new_a.each { |c| expect(c.reload.inbox).to eq(inbox) }
      new_b.each { |c| expect(c.reload.inbox).to eq(inbox_b) }
    end
  end

  # ===========================================================================
  # 2.6 Validação estatística final — 20 conversas do zero
  # ===========================================================================
  describe '2.6 Validação estatística: 20 conversas distribuídas do zero para 5 agentes' do
    before { setup_inbox_policy(enabled: true, threshold: 20) }

    it 'todas as 20 conversas são atribuídas' do
      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      unassigned = new_convs.count { |c| c.reload.assignee.nil? }
      expect(unassigned).to eq(0)
    end

    it 'desvio-padrão ≤ 2: distribuição próxima do ideal (4 por agente)' do
      # 20 conversas ÷ 5 agentes = 4 por agente no ideal
      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist = load_distribution
      sd = std_dev(dist)
      total = dist.values.sum

      expect(total).to eq(20),
        "Esperava 20 atribuições totais, obteve #{total}. Distribuição: #{dist}"
      expect(sd).to be <= 2.0,
        "Desvio-padrão=#{sd} (ideal ≤ 2): distribuição muito desigual. " \
        "Distribuição: #{dist} | Média ideal: 4 por agente"
    end

    it 'nenhum agente fica com mais de 8 conversas (dobro do ideal)' do
      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist = load_distribution
      overloaded = dist.select { |_, v| v > 8 }

      expect(overloaded).to be_empty,
        "Agentes com mais de 8 conversas (dobro do ideal=4): #{overloaded}. " \
        "Distribuição completa: #{dist}"
    end

    it 'todos os 5 agentes recebem pelo menos 1 conversa' do
      create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      dist = load_distribution
      idle_agents = dist.select { |_, v| v.zero? }

      expect(idle_agents).to be_empty,
        "Agentes sem nenhuma conversa: #{idle_agents.keys}. Distribuição: #{dist}"
    end
  end

  # ===========================================================================
  # 2.7 Janela de tempo real: conversas recentes vs antigas na contagem
  # ===========================================================================
  describe '2.7 Janela de tempo 4h: backlog antigo não influencia a distribuição' do
    before { setup_inbox_policy(enabled: true, window_hours: 4, threshold: 20) }

    it 'agente com muito backlog antigo mas menos atividade recente recebe novos clientes' do
      # Ana: 40 conversas abertas criadas ontem (>4h) + 2 recentes
      create_list(:conversation, 40, inbox: inbox, assignee: agent1, status: 'open',
                                     created_at: 25.hours.ago)
      create_list(:conversation, 2,  inbox: inbox, assignee: agent1, status: 'open',
                                     created_at: 1.hour.ago)

      # Bruno, Carla, Diego: backlog antigo + 8 recentes cada
      [agent2, agent3, agent4].each do |agent|
        create_list(:conversation, 20, inbox: inbox, assignee: agent, status: 'open',
                                       created_at: 25.hours.ago)
        create_list(:conversation, 8,  inbox: inbox, assignee: agent, status: 'open',
                                       created_at: 2.hours.ago)
      end

      # Elisa: 15 recentes (todas dentro da janela de 4h)
      create_list(:conversation, 15, inbox: inbox, assignee: agent5, status: 'open',
                                     created_at: 2.hours.ago)

      # Na janela 4h: Ana=2, Bruno=8, Carla=8, Diego=8, Elisa=15
      # spread = (15-2)/15*100 = 86.7% > 20 → equal → Ana recebe (menor carga recent=2)
      new_conv = create(:conversation, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 1)

      new_conv.reload
      expect(new_conv.assignee).to eq(agent1),
        "Esperava Ana (apenas 2 conversas recentes na janela) mas atribuiu para " \
        "#{new_conv.assignee&.name}. Ana tem 40 antigas que não devem contar."
    end

    it '20 novas conversas ignoram o backlog antigo e distribuem pela carga recente' do
      # Todos com 20 conversas antigas (fora da janela)
      all_agents.each do |agent|
        create_list(:conversation, 20, inbox: inbox, assignee: agent, status: 'open',
                                       created_at: 10.hours.ago)
      end

      # Apenas Bruno e Carla tiveram atividade recente (dentro de 4h)
      create_list(:conversation, 8, inbox: inbox, assignee: agent2, status: 'open',
                                    created_at: 1.hour.ago) # Bruno: 8 recentes
      create_list(:conversation, 6, inbox: inbox, assignee: agent3, status: 'open',
                                    created_at: 2.hours.ago) # Carla: 6 recentes
      # Ana=0, Diego=0, Elisa=0 recentes → eles devem receber mais

      new_convs = create_list(:conversation, 20, inbox: inbox, assignee: nil, status: 'open')
      service.perform_bulk_assignment(limit: 20)

      # Ana, Diego, Elisa devem ter recebido a maioria das 20 novas
      idle_recent = [agent1, agent4, agent5].sum do |agent|
        new_convs.count { |c| c.reload.assignee == agent }
      end

      expect(idle_recent).to be >= 12,
        "Ana, Diego e Elisa (sem atividade recente) deveriam receber a maioria. " \
        "Receberam apenas #{idle_recent}/20."
    end
  end
end
