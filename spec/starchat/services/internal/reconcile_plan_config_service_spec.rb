require 'rails_helper'

RSpec.describe Internal::ReconcilePlanConfigService do
  describe '#perform' do
    let(:service) { described_class.new }

    it 'does not reset installation configs or account features' do
      account = create(:account)
      account.enable_features!('disable_branding', 'audit_logs', 'cosmos_integration')
      create(:installation_config, name: 'INSTALLATION_NAME', value: 'custom-name')
      create(:installation_config, name: 'LOGO', value: '/custom-path/logo.svg')

      expect(service.perform).to eq(true)

      expect(account.reload.enabled_features.keys).to include('cosmos_integration', 'disable_branding', 'audit_logs')
      expect(InstallationConfig.find_by(name: 'INSTALLATION_NAME').value).to eq('custom-name')
      expect(InstallationConfig.find_by(name: 'LOGO').value).to eq('/custom-path/logo.svg')
    end
  end
end
