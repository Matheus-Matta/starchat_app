require 'rails_helper'

describe Conversations::PermissionFilterService do
  subject { described_class.new(account.conversations, user, account).perform }

  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:team) { create(:team, account: account) }
  let!(:inbox_1) { create(:inbox, account: account) }
  let!(:inbox_2) { create(:inbox, account: account) }

  # Conversations
  # 1. Team + Unassigned
  let!(:conv_team_unassigned) { create(:conversation, account: account, inbox: inbox_1, team: team, assignee: nil) }
  # 2. Global + Unassigned (Other Inbox, No Team)
  let!(:conv_global_unassigned) { create(:conversation, account: account, inbox: inbox_2, assignee: nil) }
  # 3. Team + Assigned (Other User)
  let!(:conv_team_assigned) { create(:conversation, account: account, inbox: inbox_1, team: team, assignee: create(:user, account: account)) }
  # 4. Global + Assigned (Other User) - Should never verify
  let!(:conv_global_assigned) { create(:conversation, account: account, inbox: inbox_2, assignee: create(:user, account: account)) }

  before do
    # Add user to team
    create(:team_member, team: team, user: user)

    # Set up AccountUser to mimic custom role behavior
    # Assuming standard agent role but with mocked permissions since we can't easily create CustomRole object in specs without factory
    au = user.account_users.find_by(account_id: account.id)
    allow(AccountUser).to receive(:find_by).with(account_id: account.id, user_id: user.id).and_return(au)
    allow(au).to receive(:permissions).and_return(permissions)
  end

  context 'with Team Manage + Unassigned Manage' do
    let(:permissions) { %w[conversation_team_manage conversation_unassigned_manage] }

    it 'returns Team conversations (assigned/unassigned) AND Global Unassigned conversations' do
      # Expectation 1: Team Unassigned -> Visible (Via Team or Unassigned)
      expect(subject).to include(conv_team_unassigned)

      # Expectation 2: Global Unassigned -> Visible (Via Unassigned Manage)
      expect(subject).to include(conv_global_unassigned)

      # Expectation 3: Team Assigned -> Visible (Via Team Manage)
      expect(subject).to include(conv_team_assigned)

      # Expectation 4: Global Assigned -> HIDDEN (No Permission)
      expect(subject).not_to include(conv_global_assigned)

      expect(subject.count).to eq(3)
    end
  end

  context 'with ONLY Team Manage' do
    let(:permissions) { ['conversation_team_manage'] }

    it 'returns ONLY Team conversations' do
      expect(subject).to include(conv_team_unassigned)
      expect(subject).to include(conv_team_assigned)

      # Global Unassigned -> HIDDEN (No Unassigned Manage)
      expect(subject).not_to include(conv_global_unassigned)

      expect(subject.count).to eq(2)
    end
  end

  context 'with ONLY Unassigned Manage' do
    let(:permissions) { ['conversation_unassigned_manage'] }

    it 'returns Global Unassigned conversations' do
      # If only unassigned manage, and team member logic is implicit in backend service
      # Backend service includes Team ID match by default for members.
      # So Team Unassigned -> Visible
      expect(subject).to include(conv_team_unassigned)
      # Global Unassigned -> Visible permissions
      expect(subject).to include(conv_global_unassigned)

      # Team Assigned -> Visible via Team ID Match (default logic)
      expect(subject).to include(conv_team_assigned)
    end
  end
end
