require 'rails_helper'

RSpec.describe Reports::CombinedEntityScope do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:team) { create(:team, account: account) }

  let(:agent_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let(:team_conversation) { create(:conversation, account: account, inbox: inbox, team: team) }
  let(:unrelated_conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

  describe '#messages' do
    # Regression: filtering by agent used to require sender_type: 'User', which only
    # matches messages the agent personally sent. Incoming (contact) messages never
    # have sender_type 'User', so an agent filter silently zeroed out
    # incoming_messages_count. Messages must be resolved via the agent's conversations,
    # the same way team/inbox already do, so both incoming and outgoing messages count.
    context 'when filtering by agent' do
      subject(:scope) { described_class.new(account, [agent.id], [], []) }

      let!(:incoming_message) { create(:message, account: account, conversation: agent_conversation, message_type: :incoming) }
      let!(:outgoing_message) { create(:message, account: account, conversation: agent_conversation, message_type: :outgoing) }
      let!(:unrelated_message) { create(:message, account: account, conversation: unrelated_conversation, message_type: :incoming) }

      it 'includes incoming and outgoing messages from the agent conversations' do
        expect(scope.messages).to contain_exactly(incoming_message, outgoing_message)
      end
    end

    context 'when filtering by team' do
      subject(:scope) { described_class.new(account, [], [team.id], []) }

      let!(:team_message) { create(:message, account: account, conversation: team_conversation, message_type: :incoming) }
      let!(:unrelated_message) { create(:message, account: account, conversation: unrelated_conversation, message_type: :incoming) }

      it 'includes messages from the team conversations' do
        expect(scope.messages).to contain_exactly(team_message)
      end
    end

    context 'when combining agent and team' do
      subject(:scope) { described_class.new(account, [agent.id], [team.id], []) }

      let!(:agent_message) { create(:message, account: account, conversation: agent_conversation, message_type: :incoming) }
      let!(:team_message) { create(:message, account: account, conversation: team_conversation, message_type: :incoming) }
      let!(:unrelated_message) { create(:message, account: account, conversation: unrelated_conversation, message_type: :incoming) }

      it 'combines both dimensions with OR' do
        expect(scope.messages).to contain_exactly(agent_message, team_message)
      end
    end

    context 'when no dimension is present' do
      subject(:scope) { described_class.new(account, [], [], []) }

      it 'returns none' do
        expect(scope.messages).to be_empty
      end
    end
  end

  describe '#conversations' do
    subject(:scope) { described_class.new(account, [agent.id], [team.id], []) }

    before do
      agent_conversation
      team_conversation
      unrelated_conversation
    end

    it 'combines agent and team conversations with OR' do
      expect(scope.conversations).to contain_exactly(agent_conversation, team_conversation)
    end
  end
end
