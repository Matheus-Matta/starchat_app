require 'rails_helper'
describe ParticipationListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  describe '#assignee_changed' do
    let(:event_name) { :assignee_changed }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    it 'adds the assignee as a participant to the conversation' do
      expect(conversation.conversation_participants.map(&:user_id)).not_to include(admin.id)
      listener.assignee_changed(event)
      expect(conversation.conversation_participants.map(&:user_id)).to include(agent.id)
    end

    it 'does not fail if the conversation participant already exists' do
      conversation.conversation_participants.create!(user: agent)
      expect { listener.assignee_changed(event) }.not_to raise_error
    end

    it 'logs a debug message if participant save fails due to a race condition' do
      allow(Rails.logger).to receive(:warn)
      allow(conversation).to receive(:conversation_participants).and_return(double)
      allow(conversation.conversation_participants).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordNotUnique)
      expect { listener.assignee_changed(event) }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with('Failed to create conversation participant for account ' \
                                                        "#{account.id} : user #{agent.id} : conversation #{conversation.id}")
    end

    context 'when prioritize_responsible_agent is active' do
      let!(:responsible_agent1) { create(:user, account: account, role: :agent) }
      let!(:responsible_agent2) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: inbox, user: responsible_agent1)
        create(:inbox_member, inbox: inbox, user: responsible_agent2)
        account.update!(settings: { 'prioritize_responsible_agent' => true })
        conversation.contact.responsible_agents << [responsible_agent1, responsible_agent2]
      end

      it 'adds all responsible agents as participants' do
        listener.assignee_changed(event)
        participant_ids = conversation.conversation_participants.pluck(:user_id)
        expect(participant_ids).to include(responsible_agent1.id, responsible_agent2.id)
      end

      it 'does not fail if a responsible agent is already a participant' do
        conversation.conversation_participants.create!(user: responsible_agent1)
        expect { listener.assignee_changed(event) }.not_to raise_error
        participant_ids = conversation.conversation_participants.pluck(:user_id)
        expect(participant_ids).to include(responsible_agent1.id, responsible_agent2.id)
      end
    end

    context 'when prioritize_responsible_agent is inactive' do
      let!(:responsible_agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: inbox, user: responsible_agent)
        account.update!(settings: { 'prioritize_responsible_agent' => false })
        conversation.contact.responsible_agents << responsible_agent
      end

      it 'does not add responsible agents as participants' do
        listener.assignee_changed(event)
        participant_ids = conversation.conversation_participants.pluck(:user_id)
        expect(participant_ids).not_to include(responsible_agent.id)
      end
    end

    context 'when contact has no responsible agents' do
      before do
        account.update!(settings: { 'prioritize_responsible_agent' => true })
      end

      it 'only adds the assignee as participant' do
        listener.assignee_changed(event)
        expect(conversation.conversation_participants.pluck(:user_id)).to eq([agent.id])
      end
    end
  end
end
