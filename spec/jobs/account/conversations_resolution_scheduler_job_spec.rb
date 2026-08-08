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

    it 'enqueues a single Conversations::ResolutionJob per account, inboxes included' do
      account
      create(:inbox, account: account, auto_resolve_duration: 1440)
      create(:inbox, account: account, auto_resolve_duration: nil)

      # The scheduler enqueues one job per account. ResolutionJob#resolve_all_for_account
      # then walks the inboxes that carry their own auto_resolve_duration or a
      # conversation flow, so no separate per-inbox job is scheduled.
      expect(Conversations::ResolutionJob).to receive(:perform_later).with(account: account).once
      expect(Conversations::ResolutionJob).not_to receive(:perform_later).with(hash_including(:inbox))

      described_class.perform_now
    end
  end
end
