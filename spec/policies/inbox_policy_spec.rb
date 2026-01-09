# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InboxPolicy, type: :policy do
  subject(:inbox_policy) { described_class }

  let(:account) { create(:account) }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:inbox) { create(:inbox) }
  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.first } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.first } }

  permissions :create?, :destroy?, :update?, :set_agent_bot? do
    context 'when administrator' do
      it { expect(inbox_policy).to permit(administrator_context, inbox) }
    end

    context 'when agent' do
      it { expect(inbox_policy).not_to permit(agent_context, inbox) }
    end
  end

  permissions :index? do
    context 'when administrator' do
      it { expect(inbox_policy).to permit(administrator_context, inbox) }
    end

    context 'when agent' do
      it { expect(inbox_policy).to permit(agent_context, inbox) }
    end
  end

  describe 'Scope' do
    let!(:team) { create(:team, account: account) }
    let!(:team_inbox) { create(:inbox, account: account) }
    let!(:team_conversation) { create(:conversation, account: account, inbox: team_inbox, team: team) }
    
    before do
       create(:team_member, user: agent, team: team)
    end

    it 'includes inbox with team conversation for agent' do
      scope = Pundit.policy_scope!(agent_context, Inbox)
      expect(scope).to include(team_inbox)
    end
  end
end
