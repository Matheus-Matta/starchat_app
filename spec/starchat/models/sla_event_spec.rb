require 'rails_helper'

RSpec.describe SlaEvent, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:applied_sla) }
    it { is_expected.to belong_to(:conversation) }
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:sla_policy) }
    it { is_expected.to belong_to(:inbox) }
  end

  describe '#push_event_data' do
    it 'returns the correct hash' do
      sla_event = create(:sla_event)
      expect(sla_event.push_event_data).to eq(
        {
          id: sla_event.id,
          event_type: 'frt',
          meta: sla_event.meta,
          created_at: sla_event.created_at.to_i,
          updated_at: sla_event.updated_at.to_i
        }
      )
    end
  end

  describe 'factory validity' do
    it 'creates a valid sla event object' do
      sla_event = create(:sla_event)
      expect(sla_event.event_type).to eq 'frt'
    end
  end

  describe 'auto-populating ids' do
    it 'fills account_id, inbox_id, and sla_policy_id on creation' do
      sla_event = create(:sla_event)

      expect(sla_event.account_id).to eq sla_event.conversation.account_id
      expect(sla_event.inbox_id).to eq sla_event.conversation.inbox_id
      expect(sla_event.sla_policy_id).to eq sla_event.applied_sla.sla_policy_id
    end
  end

  describe 'notification creation' do
    let!(:account) { create(:account) }
    let!(:assignee) { create(:user, account: account) }
    let!(:participant) { create(:user, account: account) }
    let!(:admin) { create(:user, account: account, role: :administrator) }
    let!(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, inbox: inbox, assignee: assignee, account: account) }
    let(:sla_policy) { create(:sla_policy, account: conversation.account) }
    let(:applied_sla) { create(:applied_sla, conversation: conversation, account: account, sla_policy: sla_policy) }
    let(:sla_event) { create(:sla_event, event_type: 'frt', conversation: conversation, sla_policy: sla_policy, applied_sla: applied_sla) }

    before do
      create(:user, account: account)
      create(:inbox_member, inbox: inbox, user: assignee)
      create(:inbox_member, inbox: inbox, user: participant)
      create(:conversation_participant, conversation: conversation, user: participant)
    end

    it 'creates notifications for relevant users' do
      expect { sla_event }.to change(Notification.where(notification_type: 'sla_missed_first_response'), :count).by(3)

      expect(Notification.where(user_id: assignee.id).count).to be >= 1
      expect(Notification.where(user_id: admin.id).count).to be >= 1
      expect(Notification.where(user_id: participant.id).count).to be >= 1
    end

    it 'dispatches conversation.sla_breached event' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original
      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with('conversation.sla_breached', anything, anything)

      create(:sla_event, event_type: 'frt', conversation: conversation, sla_policy: sla_policy, applied_sla: applied_sla)
    end
  end
end
