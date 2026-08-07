require 'rails_helper'

RSpec.describe AutoAssignment::AgentAssignmentService do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let!(:inbox_members) { create_list(:inbox_member, 5, inbox: inbox) }
  let!(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let!(:online_users) do
    {
      inbox_members[0].user_id.to_s => 'busy',
      inbox_members[1].user_id.to_s => 'busy',
      inbox_members[2].user_id.to_s => 'busy',
      inbox_members[3].user_id.to_s => 'online',
      inbox_members[4].user_id.to_s => 'online'
    }
  end

  before do
    inbox_members.each { |inbox_member| create(:account_user, account: account, user: inbox_member.user) }
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(online_users)
  end

  describe '#perform' do
    it 'will assign an online agent to the conversation' do
      expect(conversation.reload.assignee).to be_nil
      described_class.new(conversation: conversation, allowed_agent_ids: inbox_members.map(&:user_id).map(&:to_s)).perform
      expect(conversation.reload.assignee).not_to be_nil
    end

    it 'creates an audit log with queue snapshot data' do
      allow_any_instance_of(AutoAssignment::InboxRoundRobinService).to receive(:queue_snapshot).and_return(%w[1 2 3])

      expect do
        described_class.new(conversation: conversation, allowed_agent_ids: inbox_members.map(&:user_id).map(&:to_s)).perform
      end.to change(Starchat::AuditLog, :count).by(1)

      audit_log = Starchat::AuditLog.find_by(auditable: conversation, action: 'auto_assign')
      expect(audit_log).to be_present
      expect(audit_log.associated).to eq(account)
      expect(audit_log.audited_changes['assignment_source']).to eq('auto_assignment_legacy')
      expect(audit_log.audited_changes['queue_before']).to eq(%w[1 2 3])
    end
  end

  describe '#find_assignee' do
    it 'will return an online agent from the allowed agent ids in roud robin' do
      expect(described_class.new(conversation: conversation,
                                 allowed_agent_ids: inbox_members.map(&:user_id).map(&:to_s)).find_assignee).to eq(inbox_members[3].user)
      expect(described_class.new(conversation: conversation,
                                 allowed_agent_ids: inbox_members.map(&:user_id).map(&:to_s)).find_assignee).to eq(inbox_members[4].user)
    end
  end
end
