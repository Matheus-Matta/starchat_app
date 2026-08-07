require 'rails_helper'

RSpec.describe Internal::RemoveStaleRedisKeysJob do
  let(:account) { create(:account) }

  describe '#perform' do
    it 'enqueues ProcessStaleRedisKeysJob for the account' do
      allow(Account).to receive(:find_in_batches).and_yield([account])
      expect(Internal::ProcessStaleRedisKeysJob).to receive(:perform_later).with(account)

      described_class.perform_now
    end
  end
end
