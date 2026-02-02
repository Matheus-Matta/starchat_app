require 'rails_helper'

RSpec.describe CannedResponsePolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:admin_user) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }

  let(:custom_role_user) { create(:user) }
  let(:custom_role) { create(:custom_role, account: account, permissions: ['create_canned_response']) }

  let(:restricted_user) { create(:user) }
  let(:restricted_role) { create(:custom_role, account: account, permissions: []) }

  let(:admin_context) { { user: admin_user, account: account, account_user: admin_user.account_users.first } }
  let(:agent_context) { { user: agent_user, account: account, account_user: agent_user.account_users.first } }
  let(:custom_role_context) { { user: custom_role_user, account: account, account_user: custom_role_user.account_users.first } }
  let(:restricted_context) { { user: restricted_user, account: account, account_user: restricted_user.account_users.first } }

  let(:canned_response) { create(:canned_response, account: account) }

  before do
    create(:account_user, account: account, user: custom_role_user, role: :agent, custom_role: custom_role)
    create(:account_user, account: account, user: restricted_user, role: :agent, custom_role: restricted_role)
  end

  permissions :index? do
    it 'allows everyone (for usage)' do
      expect(subject).to permit(admin_context, canned_response)
      expect(subject).to permit(agent_context, canned_response)
      expect(subject).to permit(custom_role_context, canned_response)
      expect(subject).to permit(restricted_context, canned_response)
    end
  end

  permissions :create? do
    it 'allows administrator' do
      expect(subject).to permit(admin_context, canned_response)
    end

    it 'allows standard agent' do
      expect(subject).to permit(agent_context, canned_response)
    end

    it 'allows custom role with permission to create' do
      expect(subject).to permit(custom_role_context, canned_response)
    end

    it 'denies custom role WITHOUT permission to create' do
      expect(subject).not_to permit(restricted_context, canned_response)
    end
  end

  permissions :update? do
    it 'allows custom role with permission to update' do
      expect(subject).to permit(custom_role_context, canned_response)
    end

    it 'denies custom role WITHOUT permission to update' do
      expect(subject).not_to permit(restricted_context, canned_response)
    end
  end

  permissions :destroy? do
    it 'allows custom role with permission to destroy' do
      expect(subject).to permit(custom_role_context, canned_response)
    end

    it 'denies custom role WITHOUT permission to destroy' do
      expect(subject).not_to permit(restricted_context, canned_response)
    end
  end
end
