require 'rails_helper'

RSpec.describe Evolution::ConversationEnsurer do
  let(:account) { create(:account) }
  let(:evolution_channel) { create(:channel_evolution, account: account) }
  let(:inbox) { evolution_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5511999998888') }

  describe '.ensure!' do
    context 'when the contact has no prior conversation' do
      it 'creates a brand new conversation with status open' do
        conversation = described_class.ensure!(inbox: inbox, contact_inbox: contact_inbox)

        expect(conversation).to be_persisted
        expect(conversation).to be_open
      end

      it 'does not create more than one conversation' do
        expect do
          described_class.ensure!(inbox: inbox, contact_inbox: contact_inbox)
        end.to change(Conversation, :count).by(1)
      end
    end

    context 'when the contact already has a non-resolved conversation' do
      it 'reuses the existing conversation instead of creating a new one' do
        existing = create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox, status: :pending)

        conversation = described_class.ensure!(inbox: inbox, contact_inbox: contact_inbox)

        expect(conversation.id).to eq(existing.id)
      end
    end

    context 'when the inbox locks to a single conversation and the last one was resolved recently' do
      before { inbox.update!(lock_to_single_conversation: true) }

      it 'reopens the resolved conversation instead of creating a new one' do
        resolved = create(:conversation, account: account, inbox: inbox, contact_inbox: contact_inbox, status: :resolved)

        conversation = described_class.ensure!(inbox: inbox, contact_inbox: contact_inbox)

        expect(conversation.id).to eq(resolved.id)
        expect(conversation.reload).to be_open
      end
    end
  end
end
