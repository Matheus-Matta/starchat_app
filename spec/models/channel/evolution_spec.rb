# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Evolution, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:account) }
  # let(:user) { create(:user, account: account) } # User não é mais usado na geração do nome diretamente

  describe '#generated_instance_name' do
    context 'quando cria um novo channel' do
      let(:inbox) { create(:inbox, account: account) }
      let(:channel) { create(:channel_evolution, account: account, inbox: inbox, instance_name: nil) }

      it 'gera um instance_name único e completo' do
        instance_name = channel.instance_name

        # Deve começar com o prefixo
        expect(instance_name).to start_with('test-')

        # Deve conter timestamp Unix (10 dígitos)
        expect(instance_name).to match(/test-\d{10}/)

        # Deve conter account_id
        expect(instance_name).to include("acc#{account.id}")

        # Deve conter channel_id
        expect(instance_name).to include("ch#{channel.id}")

        # Deve conter hash único (6 caracteres hexadecimais)
        expect(instance_name).to match(/-[a-f0-9]{6}$/)
      end

      it 'gera instance_names únicos para channels diferentes' do
        channel1 = create(:channel_evolution, account: account)
        channel2 = create(:channel_evolution, account: account)

        expect(channel1.instance_name).not_to eq(channel2.instance_name)
      end
    end

    context 'validação de unicidade' do
      it 'garante que instance_name é único no banco' do
        channel1 = create(:channel_evolution, account: account)

        # Tentar criar outro com mesmo instance_name deve falhar
        channel2 = build(:channel_evolution, account: account, instance_name: channel1.instance_name)

        expect(channel2).not_to be_valid
        expect(channel2.errors[:instance_name]).to include('has already been taken')
      end
    end

    context 'formato do instance_name' do
      let(:inbox) { create(:inbox, account: account) }
      let(:channel) { create(:channel_evolution, account: account, inbox: inbox, instance_name: nil) }

      it 'tem todos os componentes no formato correto' do
        instance_name = channel.instance_name

        # Formato esperado: test-1704567890-acc5-ch12-a3f8d2
        parts = instance_name.split('-')

        # test
        expect(parts[0]).to eq('test')

        # Timestamp (10 dígitos)
        expect(parts[1]).to match(/^\d{10}$/)

        # accID
        expect(parts[2]).to start_with('acc')

        # chID
        expect(parts[3]).to start_with('ch')

        # Hash único (6 chars)
        expect(parts[4]).to match(/^[a-f0-9]{6}$/)
      end

      it 'não é muito longo para o banco de dados' do
        expect(channel.instance_name.length).to be < 255
      end
    end

    context 'aspect de tempo' do
      it 'usa timestamp atual na geração' do
        travel_to Time.zone.parse('2026-01-06 19:30:00') do
          channel = create(:channel_evolution, account: account, instance_name: nil)

          timestamp = Time.current.to_i
          expect(channel.instance_name).to include(timestamp.to_s)
        end
      end

      it 'gera nomes diferentes quando criados em momentos diferentes' do
        channel1 = nil
        channel2 = nil

        travel_to Time.zone.parse('2026-01-06 19:30:00') do
          channel1 = create(:channel_evolution, account: account, instance_name: nil)
        end

        travel_to Time.zone.parse('2026-01-06 19:30:05') do
          channel2 = create(:channel_evolution, account: account, instance_name: nil)
        end

        timestamp1 = channel1.instance_name.split('-')[1]
        timestamp2 = channel2.instance_name.split('-')[1]

        expect(timestamp1).not_to eq(timestamp2)
      end
    end

    context 'após criação' do
      it 'assign_instance_name! é chamado automaticamente após create' do
        # Factory sem instance_name explícito gera automático via callback
        channel = create(:channel_evolution, account: account, instance_name: nil)

        expect(channel.instance_name).to be_present
        expect(channel.instance_name).to start_with('test-')
      end

      it 'não sobrescreve instance_name se já existir' do
        custom_name = 'evo-custom-instance-123'
        channel = create(:channel_evolution, account: account, instance_name: custom_name)

        expect(channel.instance_name).to eq(custom_name)
      end
    end
  end
end
