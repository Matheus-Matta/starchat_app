require 'rails_helper'

RSpec.describe Account::ConversationsResolutionSchedulerJob, type: :job do
  let(:account) { create(:account) }
  let(:assistant) { create(:cosmos_assistant, account: account) }

  describe '#perform - cosmos resolutions' do
    context 'when handling different inbox types' do
      let!(:regular_inbox) { create(:inbox, account: account) }
      let!(:email_inbox) { create(:inbox, :with_email, account: account) }

      before do
        create(:cosmos_inbox, cosmos_assistant: assistant, inbox: regular_inbox)
        create(:cosmos_inbox, cosmos_assistant: assistant, inbox: email_inbox)
      end

      it 'enqueues resolution jobs only for non-email inboxes with cosmos enabled' do
        expect do
          described_class.perform_now
        end.to have_enqueued_job(Cosmos::InboxPendingConversationsResolutionJob)
          .with(regular_inbox)
          .exactly(:once)
      end

      it 'does not enqueue resolution jobs for email inboxes even with cosmos enabled' do
        expect do
          described_class.perform_now
        end.not_to have_enqueued_job(Cosmos::InboxPendingConversationsResolutionJob)
          .with(email_inbox)
      end
    end

    context 'when inbox has no cosmos enabled' do
      let!(:inbox_without_cosmos) { create(:inbox, account: create(:account)) }

      it 'does not enqueue resolution jobs' do
        expect do
          described_class.perform_now
        end.not_to have_enqueued_job(Cosmos::InboxPendingConversationsResolutionJob)
          .with(inbox_without_cosmos)
      end
    end
  end
end
