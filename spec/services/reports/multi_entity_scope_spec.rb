require 'rails_helper'

RSpec.describe Reports::MultiEntityScope do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }

  let(:agent_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let(:unrelated_conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

  describe '#messages' do
    # Regression: selecting several agents at once (an Array of ids for the same
    # dimension type) used to filter messages by sender_type: 'User', so incoming
    # (contact) messages never matched and incoming_messages_count came back as 0
    # for any agent selection. Messages must be resolved via the agents' conversations.
    context 'when dimension_type is agent' do
      subject(:scope) { described_class.new(account, 'agent', [agent.id]) }

      let!(:incoming_message) { create(:message, account: account, conversation: agent_conversation, message_type: :incoming) }
      let!(:outgoing_message) { create(:message, account: account, conversation: agent_conversation, message_type: :outgoing) }
      let!(:unrelated_message) { create(:message, account: account, conversation: unrelated_conversation, message_type: :incoming) }

      it 'includes incoming and outgoing messages from the selected agents conversations' do
        expect(scope.messages).to contain_exactly(incoming_message, outgoing_message)
      end
    end

    context 'when dimension_type is inbox' do
      subject(:scope) { described_class.new(account, 'inbox', [inbox.id]) }

      let!(:message) { create(:message, account: account, conversation: agent_conversation, inbox: inbox, message_type: :incoming) }

      it 'includes messages from the inbox' do
        expect(scope.messages).to contain_exactly(message)
      end
    end
  end

  describe '#conversations' do
    context 'when dimension_type is agent' do
      subject(:scope) { described_class.new(account, 'agent', [agent.id]) }

      before do
        agent_conversation
        unrelated_conversation
      end

      it 'returns conversations assigned to the selected agents' do
        expect(scope.conversations).to contain_exactly(agent_conversation)
      end
    end
  end

  describe '#reporting_events' do
    context 'when dimension_type is agent' do
      subject(:scope) { described_class.new(account, 'agent', [agent.id]) }

      let!(:agent_event) { create(:reporting_event, account: account, user: agent, conversation: agent_conversation) }
      let!(:other_event) { create(:reporting_event, account: account, user: other_agent, conversation: unrelated_conversation) }

      it 'returns reporting events attributed to the selected agents' do
        expect(scope.reporting_events).to contain_exactly(agent_event)
      end
    end
  end
end
