require 'rails_helper'

describe CosmosListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, account: account) }
  let(:assistant) { create(:cosmos_assistant, account: account, config: { feature_memory: true, feature_faq: true }) }

  describe '#conversation_resolved' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: user) }

    let(:event_name) { :conversation_resolved }
    let(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    before do
      create(:cosmos_inbox, cosmos_assistant: assistant, inbox: inbox)
    end

    context 'when feature_memory is enabled' do
      before do
        assistant.config['feature_memory'] = true
        assistant.config['feature_faq'] = false
        assistant.save!
      end

      it 'generates and updates notes' do
        expect(Cosmos::Llm::ContactNotesService)
          .to receive(:new)
          .with(assistant, conversation)
          .and_return(instance_double(Cosmos::Llm::ContactNotesService, generate_and_update_notes: nil))
        expect(Cosmos::Llm::ConversationFaqJob).not_to receive(:perform_later)

        listener.conversation_resolved(event)
      end
    end

    context 'when feature_faq is enabled' do
      before do
        assistant.config['feature_faq'] = true
        assistant.config['feature_memory'] = false
        assistant.save!
      end

      it 'enqueues FAQ suggestion generation' do
        expect(Cosmos::Llm::ConversationFaqJob).to receive(:perform_later).with(conversation, assistant)
        expect(Cosmos::Llm::ContactNotesService).not_to receive(:new)

        listener.conversation_resolved(event)
      end
    end
  end
end
