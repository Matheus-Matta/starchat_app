require 'rails_helper'

RSpec.describe Internal::CheckNewVersionsJob do
  subject(:job) { described_class.perform_now }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  it 'updates support info without changing local feature settings' do
    data = { 'version' => '1.2.3', 'chatwoot_support_website_token' => '123',
             'chatwoot_support_identifier_hash' => '123', 'chatwoot_support_script_url' => '123' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN').value).to eq '123'
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH').value).to eq '123'
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_SCRIPT_URL').value).to eq '123'
  end
end
