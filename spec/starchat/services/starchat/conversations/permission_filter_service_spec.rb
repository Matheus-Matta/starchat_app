require 'rails_helper'

RSpec.describe Starchat::Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  # Create conversations with different states
  let!(:assigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let!(:another_assigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: create(:user, account: account)) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:inbox2) { create(:inbox, account: account) }
  let!(:another_inbox_conversation) { create(:conversation, account: account, inbox: inbox2) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = Conversations::PermissionFilterService.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(assigned_conversation)
        expect(result).to include(unassigned_conversation)
        expect(result).to include(another_assigned_conversation)
        expect(result.count).to eq(4)
      end
    end

    context 'when user is a regular agent' do
      it 'returns all conversations in assigned inboxes' do
        result = Conversations::PermissionFilterService.new(
          account.conversations,
          agent,
          account
        ).perform

        expect(result).to include(assigned_conversation)
        expect(result).to include(unassigned_conversation)
        expect(result).to include(another_assigned_conversation)
        expect(result).not_to include(another_inbox_conversation)
        expect(result.count).to eq(3)
      end
    end

    # -------------------------------------------------------------------------
    # conversation_manage
    # -------------------------------------------------------------------------
    context 'when user has conversation_manage permission' do
      it 'returns all conversations from accessible inboxes only' do
        test_account = create(:account)
        test_inbox   = create(:inbox, account: test_account)
        test_inbox2  = create(:inbox, account: test_account)
        test_agent   = create(:user, account: test_account, role: :agent)
        create(:inbox_member, user: test_agent, inbox: test_inbox)

        test_custom_role = create(:custom_role, account: test_account, permissions: ['conversation_manage'])
        AccountUser.find_by(user: test_agent, account: test_account)
                   .update!(role: :agent, custom_role: test_custom_role)

        assigned_conv           = create(:conversation, account: test_account, inbox: test_inbox, assignee: test_agent)
        unassigned_conv         = create(:conversation, account: test_account, inbox: test_inbox, assignee: nil)
        other_assigned_conv     = create(:conversation, account: test_account, inbox: test_inbox, assignee: create(:user, account: test_account))
        other_inbox_conv        = create(:conversation, account: test_account, inbox: test_inbox2, assignee: nil)

        result = Conversations::PermissionFilterService.new(
          test_account.conversations, test_agent, test_account
        ).perform

        expect(result).to include(assigned_conv)
        expect(result).to include(unassigned_conv)
        expect(result).to include(other_assigned_conv)
        expect(result).not_to include(other_inbox_conv)
        expect(result.count).to eq(3)
      end
    end

    # -------------------------------------------------------------------------
    # conversation_team_manage
    # -------------------------------------------------------------------------
    context 'when user has conversation_team_manage permission' do
      it 'returns team conversations and conversations assigned to the agent' do
        test_account = create(:account)
        test_team    = create(:team, account: test_account)
        test_agent   = create(:user, account: test_account, role: :agent)
        create(:team_member, team: test_team, user: test_agent)

        # Disable auto_assignment so conversations assigned to non-inbox-members
        # don't have their assignee cleared by Chatwoot's AutoAssignmentHandler.
        test_inbox  = create(:inbox, account: test_account, enable_auto_assignment: false)
        test_inbox2 = create(:inbox, account: test_account, enable_auto_assignment: false)

        test_custom_role = create(:custom_role, account: test_account, permissions: ['conversation_team_manage'])
        AccountUser.find_by(user: test_agent, account: test_account)
                   .update!(role: :agent, custom_role: test_custom_role)

        mine              = create(:conversation, account: test_account, inbox: test_inbox, assignee: test_agent)
        team_unassigned   = create(:conversation, account: test_account, inbox: test_inbox, team: test_team, assignee: nil)
        team_assigned     = create(:conversation, account: test_account, inbox: test_inbox, team: test_team,
                                                  assignee: create(:user, account: test_account))
        global_unassigned = create(:conversation, account: test_account, inbox: test_inbox2, assignee: nil)
        global_assigned   = create(:conversation, account: test_account, inbox: test_inbox2,
                                                  assignee: create(:user, account: test_account))

        result = Conversations::PermissionFilterService.new(
          test_account.conversations, test_agent, test_account
        ).perform

        # Agent's own conversation is visible (conversation_team_manage includes "assigned to self")
        expect(result).to include(mine)
        # Team conversations are visible
        expect(result).to include(team_unassigned)
        expect(result).to include(team_assigned)
        # Conversations outside team and not assigned to agent are hidden
        expect(result).not_to include(global_unassigned)
        expect(result).not_to include(global_assigned)
        expect(result.count).to eq(3)
      end
    end

    # -------------------------------------------------------------------------
    # conversation_unassigned_manage
    # Unassigned conversations must be scoped to the agent's accessible inboxes/teams.
    # -------------------------------------------------------------------------
    context 'when user has conversation_unassigned_manage permission' do
      it 'returns unassigned conversations from accessible inboxes and mine, but NOT from inaccessible inboxes' do
        test_account = create(:account)
        # Disable auto_assignment to prevent Chatwoot from reassigning conversations
        # with non-inbox-member assignees to the test agent.
        test_inbox   = create(:inbox, account: test_account, enable_auto_assignment: false)
        test_inbox2  = create(:inbox, account: test_account, enable_auto_assignment: false)
        test_agent   = create(:user, account: test_account, role: :agent)
        create(:inbox_member, user: test_agent, inbox: test_inbox)

        test_custom_role = create(:custom_role, account: test_account, permissions: %w[conversation_unassigned_manage])
        AccountUser.find_by(user: test_agent, account: test_account)
                   .update!(role: :agent, custom_role: test_custom_role)

        assigned_conv           = create(:conversation, account: test_account, inbox: test_inbox, assignee: test_agent)
        unassigned_conv         = create(:conversation, account: test_account, inbox: test_inbox, assignee: nil)
        other_assigned_conv     = create(:conversation, account: test_account, inbox: test_inbox,
                                                        assignee: create(:user, account: test_account))
        # Unassigned in inbox the agent has NO access to – must be excluded
        other_inbox_conv        = create(:conversation, account: test_account, inbox: test_inbox2, assignee: nil)

        result = Conversations::PermissionFilterService.new(
          test_account.conversations, test_agent, test_account
        ).perform

        expect(result).to include(unassigned_conv)
        expect(result).to include(assigned_conv)
        expect(result).not_to include(other_assigned_conv)
        expect(result).not_to include(other_inbox_conv)
        expect(result.count).to eq(2)
      end
    end

    # -------------------------------------------------------------------------
    # conversation_participating_manage
    # -------------------------------------------------------------------------
    context 'when user has conversation_participating_manage permission' do
      it 'returns only conversations assigned to the agent' do
        test_account = create(:account)
        test_inbox   = create(:inbox, account: test_account)
        test_inbox2  = create(:inbox, account: test_account)
        test_agent   = create(:user, account: test_account, role: :agent)
        create(:inbox_member, user: test_agent, inbox: test_inbox)

        test_custom_role = create(:custom_role, account: test_account, permissions: %w[conversation_participating_manage])
        AccountUser.find_by(user: test_agent, account: test_account)
                   .update!(role: :agent, custom_role: test_custom_role)

        other_conversation  = create(:conversation, account: test_account, inbox: test_inbox)
        assigned_conv       = create(:conversation, account: test_account, inbox: test_inbox, assignee: test_agent)
        other_inbox_conv    = create(:conversation, account: test_account, inbox: test_inbox2, assignee: nil)

        result = Conversations::PermissionFilterService.new(
          test_account.conversations, test_agent, test_account
        ).perform

        expect(result.count).to eq(1)
        expect(result.first.assignee).to eq(test_agent)
        expect(result).to include(assigned_conv)
        expect(result).not_to include(other_conversation)
        expect(result).not_to include(other_inbox_conv)
      end
    end

    # -------------------------------------------------------------------------
    # Hierarchical priority: unassigned_manage + participating_manage
    # -------------------------------------------------------------------------
    context 'when user has both participating and unassigned permissions (hierarchical test)' do
      it 'gives higher priority to unassigned_manage over participating_manage' do
        test_account = create(:account)
        # Disable auto_assignment to prevent Chatwoot from reassigning conversations
        # with non-inbox-member assignees to the test agent.
        test_inbox   = create(:inbox, account: test_account, enable_auto_assignment: false)
        test_inbox2  = create(:inbox, account: test_account, enable_auto_assignment: false)
        test_agent   = create(:user, account: test_account, role: :agent)
        create(:inbox_member, user: test_agent, inbox: test_inbox)

        permissions      = %w[conversation_participating_manage conversation_unassigned_manage]
        test_custom_role = create(:custom_role, account: test_account, permissions: permissions)
        AccountUser.find_by(user: test_agent, account: test_account)
                   .update!(role: :agent, custom_role: test_custom_role)

        assigned_to_agent       = create(:conversation, account: test_account, inbox: test_inbox, assignee: test_agent)
        unassigned_conv         = create(:conversation, account: test_account, inbox: test_inbox, assignee: nil)
        other_assigned_conv     = create(:conversation, account: test_account, inbox: test_inbox,
                                                        assignee: create(:user, account: test_account))
        # In inaccessible inbox – must stay hidden
        other_inbox_conv        = create(:conversation, account: test_account, inbox: test_inbox2, assignee: nil)

        result = Conversations::PermissionFilterService.new(
          test_account.conversations, test_agent, test_account
        ).perform

        expect(result.count).to eq(2)
        expect(result).to include(unassigned_conv)
        expect(result).to include(assigned_to_agent)
        expect(result).not_to include(other_assigned_conv)
        expect(result).not_to include(other_inbox_conv)
      end
    end

    # -------------------------------------------------------------------------
    # No conversation permission – should return nothing
    # -------------------------------------------------------------------------
    context 'when user has no conversation permission (only contact_manage)' do
      it 'returns no conversations' do
        test_account = create(:account)
        test_inbox   = create(:inbox, account: test_account)
        test_agent   = create(:user, account: test_account, role: :agent)
        create(:inbox_member, user: test_agent, inbox: test_inbox)

        test_custom_role = create(:custom_role, account: test_account, permissions: %w[contact_manage])
        AccountUser.find_by(user: test_agent, account: test_account)
                   .update!(role: :agent, custom_role: test_custom_role)

        create(:conversation, account: test_account, inbox: test_inbox, assignee: test_agent)

        result = Conversations::PermissionFilterService.new(
          test_account.conversations, test_agent, test_account
        ).perform

        expect(result.count).to eq(0)
      end
    end
  end
end

