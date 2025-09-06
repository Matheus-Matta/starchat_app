require 'rails_helper'

RSpec.describe Cosmos::Copilot::ResponseJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:assistant) { create(:cosmos_assistant, account: account) }
  let(:copilot_thread) { create(:cosmos_copilot_thread, account: account, user: user, assistant: assistant) }
  let(:conversation_id) { 123 }
  let(:message) { { 'content' => 'Test message' } }

  describe '#perform' do
    let(:chat_service) { instance_double(Cosmos::Copilot::ChatService) }

    before do
      allow(Cosmos::Copilot::ChatService).to receive(:new).with(
        assistant,
        user_id: user.id,
        copilot_thread_id: copilot_thread.id,
        conversation_id: conversation_id
      ).and_return(chat_service)
      allow(chat_service).to receive(:generate_response).with(message)
    end

    it 'initializes ChatService with correct parameters and calls generate_response' do
      expect(Cosmos::Copilot::ChatService).to receive(:new).with(
        assistant,
        user_id: user.id,
        copilot_thread_id: copilot_thread.id,
        conversation_id: conversation_id
      )
      expect(chat_service).to receive(:generate_response).with(message)
      described_class.perform_now(
        assistant: assistant,
        conversation_id: conversation_id,
        user_id: user.id,
        copilot_thread_id: copilot_thread.id,
        message: message
      )
    end
  end
end
