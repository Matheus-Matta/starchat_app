require 'rails_helper'

RSpec.describe Cosmos::InboxPendingConversationsResolutionJob, type: :job do
  let!(:inbox) { create(:inbox) }
  let!(:resolvable_pending_conversation) { create(:conversation, inbox: inbox, last_activity_at: 2.hours.ago, status: :pending) }
  let!(:recent_pending_conversation) { create(:conversation, inbox: inbox, last_activity_at: 1.minute.ago, status: :pending) }
  let!(:open_conversation) { create(:conversation, inbox: inbox, last_activity_at: 1.hour.ago, status: :open) }

  let!(:cosmos_assistant) { create(:cosmos_assistant, account: inbox.account) }

  before do
    create(:cosmos_inbox, inbox: inbox, cosmos_assistant: cosmos_assistant)
    stub_const('Limits::BULK_ACTIONS_LIMIT', 2)
    inbox.reload
  end

  it 'queues the job' do
    expect { described_class.perform_later(inbox) }
      .to have_enqueued_job.on_queue('low')
  end

  context 'when cosmos_tasks is disabled' do
    it 'resolves pending conversations inactive for over 1 hour' do
      described_class.perform_now(inbox)

      expect(resolvable_pending_conversation.reload.status).to eq('resolved')
    end

    it 'does not resolve recent pending conversations' do
      described_class.perform_now(inbox)

      expect(recent_pending_conversation.reload.status).to eq('pending')
    end

    it 'does not affect open conversations' do
      described_class.perform_now(inbox)

      expect(open_conversation.reload.status).to eq('open')
    end

    it 'does not call ConversationCompletionService' do
      allow(Cosmos::ConversationCompletionService).to receive(:new)

      described_class.perform_now(inbox)

      expect(Cosmos::ConversationCompletionService).not_to have_received(:new)
    end
  end

  it 'creates exactly one outgoing message with configured content' do
    custom_message = 'This is a custom resolution message.'
    cosmos_assistant.update!(config: { 'resolution_message' => custom_message })

    described_class.perform_now(inbox)

    expect(resolvable_pending_conversation.reload.status).to eq('resolved')
    expect(resolvable_pending_conversation.messages.outgoing.count).to eq(1)
    expect(resolvable_pending_conversation.messages.outgoing.last.content).to eq(custom_message)
  end

  it 'creates an outgoing message with default auto resolution message if not configured' do
    cosmos_assistant.update!(config: {})

    described_class.perform_now(inbox)

    expect(resolvable_pending_conversation.reload.status).to eq('resolved')
    expect(resolvable_pending_conversation.messages.outgoing.count).to eq(1)
  end

  it 'adds the correct activity message after resolution by Cosmos' do
    described_class.perform_now(inbox)
    expected_content = I18n.t('conversations.activity.cosmos.resolved', user_name: cosmos_assistant.name)
    expect(Conversations::ActivityMessageJob)
      .to have_been_enqueued.with(
        resolvable_pending_conversation,
        {
          account_id: resolvable_pending_conversation.account_id,
          inbox_id: resolvable_pending_conversation.inbox_id,
          message_type: :activity,
          content: expected_content
        }
      )
  end
end
