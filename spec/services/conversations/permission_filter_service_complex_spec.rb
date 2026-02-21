require 'rails_helper'

describe Conversations::PermissionFilterService do
  subject { described_class.new(account.conversations, user, account).perform }

  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:team) { create(:team, account: account) }
  # Inbox 1 is used for team conversations; disable auto_assignment to keep the
  # assignee stable during the test (otherwise Chatwoot clears the assignee when
  # the agent is not an inbox member).
  let!(:inbox_1) { create(:inbox, account: account, enable_auto_assignment: false) }
  let!(:inbox_2) { create(:inbox, account: account, enable_auto_assignment: false) }

  # Conversations
  # 1. Team + Unassigned (user has team access)
  let!(:conv_team_unassigned) { create(:conversation, account: account, inbox: inbox_1, team: team, assignee: nil) }
  # 2. Global + Unassigned (inbox_2, no team – user has NO access to inbox_2)
  let!(:conv_global_unassigned) { create(:conversation, account: account, inbox: inbox_2, assignee: nil) }
  # 3. Team + Assigned (Other User)
  # Use update_columns to bypass ALL callbacks (including AutoAssignmentHandler)
  # and guarantee the assignee_id is persisted in the DB.
  let!(:conv_team_assigned) do
    other_user = create(:user, account: account)
    conv = create(:conversation, account: account, inbox: inbox_1, team: team)
    conv.update_columns(assignee_id: other_user.id)
    conv
  end
  # 4. Global + Assigned (Other User – user has NO access)
  let!(:conv_global_assigned) do
    other_user = create(:user, account: account)
    conv = create(:conversation, account: account, inbox: inbox_2)
    conv.update_columns(assignee_id: other_user.id)
    conv
  end

  before do
    # User belongs only to the team – NOT an inbox member of inbox_1 or inbox_2
    create(:team_member, team: team, user: user)

    au = user.account_users.find_by(account_id: account.id)
    allow(AccountUser).to receive(:find_by).with(account_id: account.id, user_id: user.id).and_return(au)
    allow(au).to receive(:permissions).and_return(permissions)
    # Simulate custom_role presence so user_has_custom_role? returns true
    allow(au).to receive(:custom_role_id).and_return(999)
    allow(au).to receive(:role).and_return('agent')
  end

  # ---------------------------------------------------------------------------
  # conversation_team_manage + conversation_unassigned_manage
  # ---------------------------------------------------------------------------
  context 'with Team Manage + Unassigned Manage' do
    let(:permissions) { %w[conversation_team_manage conversation_unassigned_manage] }

    it 'returns team conversations (assigned/unassigned) but NOT conversations from inaccessible inboxes' do
      # Team conversations are visible
      expect(subject).to include(conv_team_unassigned)
      expect(subject).to include(conv_team_assigned)

      # conv_global_unassigned is in inbox_2 with no team – user has NO access
      expect(subject).not_to include(conv_global_unassigned)
      # conv_global_assigned is in inbox_2 – also inaccessible
      expect(subject).not_to include(conv_global_assigned)

      expect(subject.count).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # conversation_team_manage ONLY
  # ---------------------------------------------------------------------------
  context 'with ONLY Team Manage' do
    let(:permissions) { ['conversation_team_manage'] }

    it 'returns ONLY conversations belonging to the user\'s team' do
      expect(subject).to include(conv_team_unassigned)
      expect(subject).to include(conv_team_assigned)

      expect(subject).not_to include(conv_global_unassigned)
      expect(subject).not_to include(conv_global_assigned)

      expect(subject.count).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # conversation_unassigned_manage ONLY
  # Unassigned conversations must be scoped to accessible inboxes/teams only.
  # ---------------------------------------------------------------------------
  context 'with ONLY Unassigned Manage' do
    let(:permissions) { ['conversation_unassigned_manage'] }

    it 'returns unassigned conversations ONLY from accessible inboxes and teams' do
      # conv_team_unassigned is unassigned and in the user's team → visible
      expect(subject).to include(conv_team_unassigned)

      # conv_global_unassigned is unassigned but in inbox_2 (no access) → HIDDEN
      expect(subject).not_to include(conv_global_unassigned)

      # conv_team_assigned is assigned to another user, not mine → HIDDEN
      expect(subject).not_to include(conv_team_assigned)

      # conv_global_assigned is assigned to another user in inaccessible inbox → HIDDEN
      expect(subject).not_to include(conv_global_assigned)

      expect(subject.count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # conversation_manage (full access – scoped to accessible inboxes/teams)
  # ---------------------------------------------------------------------------
  context 'with Full Manage' do
    let(:permissions) { ['conversation_manage'] }

    it 'returns all conversations in accessible inboxes and teams' do
      # Team conversations are accessible
      expect(subject).to include(conv_team_unassigned)
      expect(subject).to include(conv_team_assigned)

      # inbox_2 conversations: user has no inbox membership and no team → NOT accessible
      expect(subject).not_to include(conv_global_unassigned)
      expect(subject).not_to include(conv_global_assigned)

      expect(subject.count).to eq(2)
    end
  end
end
