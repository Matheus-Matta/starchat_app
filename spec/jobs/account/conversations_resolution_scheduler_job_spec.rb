require 'rails_helper'

RSpec.describe Account::ConversationsResolutionSchedulerJob do
  subject(:job) { described_class.perform_later }

  let!(:account) { create(:account) }

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  describe '#perform' do
    let(:account) { create(:account, auto_resolve_after: 10 * 60 * 24) }
    let(:account_without_auto_resolve) { create(:account, auto_resolve_after: nil) }
    
    it 'enqueues Conversations::ResolutionJob globally for accounts with auto resolve' do
      account
      account_without_auto_resolve
      
      expect(Conversations::ResolutionJob).to receive(:perform_later).with(account: account).once
      expect(Conversations::ResolutionJob).not_to receive(:perform_later).with(account: account_without_auto_resolve)

      described_class.perform_now
    end

    it 'enqueues Conversations::ResolutionJob individually for inboxes with custom auto resolve' do
      account
      inbox_custom = create(:inbox, account: account, auto_resolve_duration: 1440)
      inbox_default = create(:inbox, account: account, auto_resolve_duration: nil)

      # Expect global first
      expect(Conversations::ResolutionJob).to receive(:perform_later).with(account: account).once
      
      # Expect inbox specifically
      expect(Conversations::ResolutionJob).to receive(:perform_later).with(account: account, inbox: inbox_custom).once

      described_class.perform_now
    end
  end
end
