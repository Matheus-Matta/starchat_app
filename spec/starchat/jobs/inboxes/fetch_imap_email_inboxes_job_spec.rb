require 'rails_helper'

RSpec.describe Inboxes::FetchImapEmailInboxesJob do
  context 'when starchats_cloud is enabled' do
    let(:account) { create(:account) }
    let(:premium_account) { create(:account) }
    let(:imap_email_channel) { create(:channel_email, imap_enabled: true, account: account) }
    let(:premium_imap_channel) { create(:channel_email, imap_enabled: true, account: premium_account) }

    before do
      InstallationConfig.find_or_initialize_by(name: 'DEPLOYMENT_ENV').update!(value: 'cloud')
    end

    it 'processes every imap inbox regardless of plan' do
      expect(Inboxes::FetchImapEmailsJob).to receive(:perform_later).with(imap_email_channel)
      expect(Inboxes::FetchImapEmailsJob).to receive(:perform_later).with(premium_imap_channel)
      described_class.perform_now
    end
  end
end
