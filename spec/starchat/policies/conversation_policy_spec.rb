require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  # Disable auto_assignment to prevent AutoAssignmentHandler from reassigning
  # conversations during tests, which would corrupt assignee expectations.
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:other_inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:team) { create(:team, account: account) }
  let(:agent_account_user) { agent.account_users.find_by(account: account) }
  let(:context) { { user: agent, account: account, account_user: agent_account_user } }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
  end

  permissions :show? do
    # -------------------------------------------------------------------
    # conversation_unassigned_manage
    # -------------------------------------------------------------------
    context 'when role grants conversation_unassigned_manage' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_unassigned_manage']) }

      before { agent_account_user.update!(role: :agent, custom_role: custom_role) }

      it 'allows access to conversations assigned to the agent' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
        expect(subject).to permit(context, conversation)
      end

      it 'allows access to unassigned conversations in the agent\'s inbox' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
        expect(subject).to permit(context, conversation)
      end

      it 'denies access to conversations assigned to someone else' do
        other_agent = create(:user, account: account, role: :agent)
        conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
        expect(subject).not_to permit(context, conversation)
      end

      it 'denies access to unassigned conversations in an inaccessible inbox' do
        conversation = create(:conversation, account: account, inbox: other_inbox, assignee: nil)
        expect(subject).not_to permit(context, conversation)
      end
    end

    # -------------------------------------------------------------------
    # conversation_team_manage
    # -------------------------------------------------------------------
    context 'when role grants conversation_team_manage' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_team_manage']) }

      before do
        agent_account_user.update!(role: :agent, custom_role: custom_role)
        create(:team_member, team: team, user: agent)
      end

      it 'allows access to conversations assigned to the agent' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
        expect(subject).to permit(context, conversation)
      end

      it 'allows access to conversations in the agent\'s team' do
        conversation = create(:conversation, account: account, inbox: inbox, team: team,
                                            assignee: create(:user, account: account))
        expect(subject).to permit(context, conversation)
      end

      it 'allows access to unassigned conversations in the agent\'s team' do
        conversation = create(:conversation, account: account, inbox: inbox, team: team, assignee: nil)
        expect(subject).to permit(context, conversation)
      end

      it 'denies access to conversations outside the team and not assigned to the agent' do
        other_agent = create(:user, account: account, role: :agent)
        conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
        expect(subject).not_to permit(context, conversation)
      end

      it 'denies access to conversations in a different team' do
        other_team = create(:team, account: account)
        conversation = create(:conversation, account: account, inbox: inbox, team: other_team,
                                            assignee: create(:user, account: account))
        expect(subject).not_to permit(context, conversation)
      end
    end

    # -------------------------------------------------------------------
    # conversation_participating_manage
    # -------------------------------------------------------------------
    context 'when role grants conversation_participating_manage' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_participating_manage']) }

      before { agent_account_user.update!(role: :agent, custom_role: custom_role) }

      it 'allows access to conversations assigned to the agent' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
        expect(subject).to permit(context, conversation)
      end

      it 'allows access to conversations where the agent is a participant' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
        create(:conversation_participant, conversation: conversation, account: account, user: agent)
        expect(subject).to permit(context, conversation)
      end

      it 'denies access to unassigned conversations where agent is not a participant' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
        expect(subject).not_to permit(context, conversation)
      end

      it 'denies access to conversations assigned to another agent' do
        other_agent = create(:user, account: account, role: :agent)
        conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
        expect(subject).not_to permit(context, conversation)
      end
    end

    # -------------------------------------------------------------------
    # conversation_manage (full access within accessible scope)
    # -------------------------------------------------------------------
    context 'when role grants conversation_manage' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_manage']) }

      before { agent_account_user.update!(role: :agent, custom_role: custom_role) }

      it 'allows access to any conversation in the accessible inbox' do
        other_agent = create(:user, account: account, role: :agent)
        conversation = create(:conversation, account: account, inbox: inbox, assignee: other_agent)
        expect(subject).to permit(context, conversation)
      end

      it 'allows access to unassigned conversations in the accessible inbox' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
        expect(subject).to permit(context, conversation)
      end
    end

    # -------------------------------------------------------------------
    # No conversation permissions
    # -------------------------------------------------------------------
    context 'when custom role has no conversation permissions' do
      let(:custom_role) { create(:custom_role, account: account, permissions: ['contact_manage']) }

      before { agent_account_user.update!(role: :agent, custom_role: custom_role) }

      it 'denies access to any conversation' do
        conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
        expect(subject).not_to permit(context, conversation)
      end
    end
  end
end
