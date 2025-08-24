require 'rails_helper'

RSpec.describe SlaPolicyDrop do
  let(:sla_policy) { FactoryBot.create(:sla_policy) }
  subject(:drop) { described_class.new(sla_policy) }

  describe '#name' do
    it 'returns the name from sla_policy' do
      expect(drop.name).to eq(sla_policy.name)
    end
  end

  describe '#description' do
    it 'returns the description from sla_policy' do
      expect(drop.description).to eq(sla_policy.description)
    end
  end
end
