require 'rails_helper'

describe VapidService do
  subject(:trigger) { described_class }

  describe 'execute' do
    context 'when called with default options' do
      before do
        GlobalConfig.clear_cache
      end

      it 'hit DB for the first call' do
        expect(InstallationConfig).to receive(:find_by)
        GlobalConfig.get('VAPID_KEYS')
      end

      it 'get public key from env' do
        InstallationConfig.where(name: 'VAPID_KEYS').delete_all
        GlobalConfig.clear_cache
        ENV['VAPID_PUBLIC_KEY'] = 'test'
        expect(described_class.public_key).to eq 'test'
        ENV['VAPID_PUBLIC_KEY'] = nil
      end

      it 'get private key from env' do
        InstallationConfig.where(name: 'VAPID_KEYS').delete_all
        GlobalConfig.clear_cache
        ENV['VAPID_PRIVATE_KEY'] = 'test'
        expect(described_class.private_key).to eq 'test'
        ENV['VAPID_PRIVATE_KEY'] = nil
      end

      it 'clears cache and fetch from DB next time, when clear_cache is called' do
        # this loads from DB and is cached
        GlobalConfig.get('VAPID_KEYS')

        # clears the cache
        GlobalConfig.clear_cache

        # should be loaded from DB
        expect(InstallationConfig).to receive(:find_by).with({ name: 'VAPID_KEYS' }).and_return(nil)
        GlobalConfig.get('VAPID_KEYS')
      end
    end
  end
end
