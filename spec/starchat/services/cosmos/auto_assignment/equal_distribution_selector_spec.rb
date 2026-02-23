require 'rails_helper'

RSpec.describe Starchat::AutoAssignment::EqualDistributionSelector do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent1) { create(:user, account: account, role: :agent, availability: :online) }
  let(:agent2) { create(:user, account: account, role: :agent, availability: :online) }
  let(:agent3) { create(:user, account: account, role: :agent, availability: :online) }
  let(:member1) { create(:inbox_member, inbox: inbox, user: agent1) }
  let(:member2) { create(:inbox_member, inbox: inbox, user: agent2) }
  let(:member3) { create(:inbox_member, inbox: inbox, user: agent3) }

  # Round-robin fallback simulado para isolar testes da fila Redis
  let(:rr_fallback) { instance_double('AutoAssignment::RoundRobinSelector') }

  # Helper para construir o seletor com parâmetros padrão
  def build_selector(window_hours: 24, threshold: 20)
    described_class.new(
      inbox: inbox,
      window_hours: window_hours,
      balance_threshold: threshold,
      round_robin_fallback: rr_fallback
    )
  end

  describe '#select_agent' do
    context 'retorno nil / agente único' do
      let(:selector) { build_selector }

      it 'retorna nil quando a lista de agentes está vazia' do
        expect(selector.select_agent([])).to be_nil
      end

      it 'retorna o único agente disponível independentemente da carga' do
        create_list(:conversation, 50, inbox: inbox, assignee: agent1, status: 'open')
        expect(selector.select_agent([member1])).to eq(agent1)
      end
    end

    context 'quando a dispersão de carga EXCEDE o limiar (usa equal distribution)' do
      # threshold=20 → spread precisa ser > 20% para ativar equal distribution

      it 'seleciona agente com menor carga: 20 / 30 / 5 → spread=83% > 20%' do
        # Agente 1: 20, Agente 2: 30, Agente 3: 5
        # spread = (30-5)/30*100 = 83.3% → equal distribution
        create_list(:conversation, 20, inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 30, inbox: inbox, assignee: agent2, status: 'open')
        create_list(:conversation, 5,  inbox: inbox, assignee: agent3, status: 'open')

        selector = build_selector(threshold: 20)
        expect(selector.select_agent([member1, member2, member3])).to eq(agent3)
      end

      it 'seleciona agente com menor carga: 8 / 14 → spread=43% > 20%' do
        create_list(:conversation, 8,  inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 14, inbox: inbox, assignee: agent2, status: 'open')

        selector = build_selector(threshold: 20)
        expect(selector.select_agent([member1, member2])).to eq(agent1)
      end

      it 'ignora conversas resolvidas no contador' do
        # Agente 1: 1 aberta + 10 resolvidas → raw=1
        create(:conversation, inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 10, inbox: inbox, assignee: agent1, status: 'resolved')

        # Agente 2: 5 abertas
        create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
        # spread = (5-1)/5*100 = 80% > 20 → equal

        selector = build_selector(threshold: 20)
        expect(selector.select_agent([member1, member2])).to eq(agent1)
      end

      it 'prioriza agente sem nenhuma conversa quando os outros têm carga alta' do
        create_list(:conversation, 10, inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 8,  inbox: inbox, assignee: agent2, status: 'open')
        # Agente 3: 0 conversas → spread = (10-0)/10*100 = 100% > 20

        selector = build_selector(threshold: 20)
        expect(selector.select_agent([member1, member2, member3])).to eq(agent3)
      end
    end

    context 'quando a dispersão de carga está DENTRO do limiar (usa round-robin)' do
      # threshold=20 → spread <= 20% → round-robin

      it 'delega ao round-robin quando cargas são: 10 / 11 / 12 → spread=17%' do
        create_list(:conversation, 10, inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 11, inbox: inbox, assignee: agent2, status: 'open')
        create_list(:conversation, 12, inbox: inbox, assignee: agent3, status: 'open')
        # spread = (12-10)/12*100 = 16.7% ≤ 20 → round-robin

        available = [member1, member2, member3]
        allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent1)

        selector = build_selector(threshold: 20)
        result = selector.select_agent(available)

        expect(rr_fallback).to have_received(:select_agent).with(available)
        expect(result).to eq(agent1)
      end

      it 'delega ao round-robin quando todos os agentes têm a mesma carga (empate total)' do
        create(:conversation, inbox: inbox, assignee: agent1, status: 'open')
        create(:conversation, inbox: inbox, assignee: agent2, status: 'open')
        create(:conversation, inbox: inbox, assignee: agent3, status: 'open')
        # spread = 0% ≤ 20 → round-robin

        available = [member1, member2, member3]
        allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent2)

        selector = build_selector(threshold: 20)
        result = selector.select_agent(available)

        expect(rr_fallback).to have_received(:select_agent)
        expect(result).to eq(agent2)
      end

      it 'delega ao round-robin quando todos os agentes têm zero conversas' do
        available = [member1, member2, member3]
        allow(rr_fallback).to receive(:select_agent).with(available).and_return(agent3)

        selector = build_selector(threshold: 20)
        result = selector.select_agent(available)

        expect(rr_fallback).to have_received(:select_agent)
        expect(result).to eq(agent3)
      end
    end

    context 'com threshold=0 (sem tolerância — sempre usa equal distribution)' do
      it 'usa equal distribution mesmo quando as cargas diferem em 1 conversa' do
        create_list(:conversation, 5, inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 6, inbox: inbox, assignee: agent2, status: 'open')
        # spread = (6-5)/6*100 = 16.7% > 0 → equal

        selector = build_selector(threshold: 0)
        expect(selector.select_agent([member1, member2])).to eq(agent1)
      end

      it 'usa round-robin apenas quando spread=0 (cargas idênticas)' do
        create_list(:conversation, 5, inbox: inbox, assignee: agent1, status: 'open')
        create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
        # spread = 0% == 0 → round-robin (allzero check)

        available = [member1, member2]
        allow(rr_fallback).to receive(:select_agent).and_return(agent1)

        selector = build_selector(threshold: 0)
        selector.select_agent(available)

        expect(rr_fallback).to have_received(:select_agent)
      end
    end

    context 'quando a janela de tempo filtra conversas antigas' do
      it 'não conta conversas fora da janela de 2h' do
        # Agente 1: 9 conversas antigas + 1 recente = 1 na janela
        create_list(:conversation, 9, inbox: inbox, assignee: agent1, status: 'open',
                                      created_at: 5.hours.ago)
        create(:conversation, inbox: inbox, assignee: agent1, status: 'open')

        # Agente 2: 5 recentes → spread=(5-1)/5*100=80% > 20
        create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')

        selector = build_selector(window_hours: 2, threshold: 20)
        expect(selector.select_agent([member1, member2])).to eq(agent1)
      end
    end

    context 'quando window_hours é 0 (sem filtro de tempo)' do
      it 'conta todas as conversas abertas independentemente da data' do
        create(:conversation, inbox: inbox, assignee: agent1, status: 'open', created_at: 1.year.ago)
        create_list(:conversation, 5, inbox: inbox, assignee: agent2, status: 'open')
        # spread = (5-1)/5*100 = 80% > 20 → equal

        selector = build_selector(window_hours: 0, threshold: 20)
        expect(selector.select_agent([member1, member2])).to eq(agent1)
      end
    end
  end
end
