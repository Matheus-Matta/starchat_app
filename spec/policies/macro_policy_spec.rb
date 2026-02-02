require 'rails_helper'

RSpec.describe MacroPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:admin_user) { create(:user, account: account, role: :administrator) }
  let(:agent_user) { create(:user, account: account, role: :agent) }

  let(:custom_role_user) { create(:user) }
  let(:custom_role) { create(:custom_role, account: account, permissions: ['create_macro']) }
  
  let(:restricted_user) { create(:user) }
  let(:restricted_role) { create(:custom_role, account: account, permissions: []) }

  before do
    create(:account_user, account: account, user: custom_role_user, role: :agent, custom_role: custom_role)
    create(:account_user, account: account, user: restricted_user, role: :agent, custom_role: restricted_role)
  end

  let(:admin_context) { { user: admin_user, account: account, account_user: admin_user.account_users.first } }
  let(:agent_context) { { user: agent_user, account: account, account_user: agent_user.account_users.first } }
  let(:custom_role_context) { { user: custom_role_user, account: account, account_user: custom_role_user.account_users.first } }
  let(:restricted_context) { { user: restricted_user, account: account, account_user: restricted_user.account_users.first } }

  let(:macro) { create(:macro, account: account, created_by: agent_user) }

  permissions :index? do
    it 'allows administrator' do
      expect(subject).to permit(admin_context, macro)
    end
    it 'allows standard agent' do
      expect(subject).to permit(agent_context, macro)
    end
    it 'allows custom role with permission' do
      expect(subject).to permit(custom_role_context, macro)
    end
    it 'denies custom role WITHOUT permission' do
      # Actually index is typically checking Class, not record. But Pundit Helper allows record.
      # My policy: index? { ... }
      # Wait, previously I had index? checking permission.
      # But for usage reasons I kept index? true for CannedResponse.
      # For MacroPolicy, did I restrict it?
      # Step 160: index? NOT modified (it was true).
      # Wait, I did NOT restrict index for MacroPolicy in Step 160!
      expect(subject).to permit(restricted_context, macro)
    end
  end

  permissions :create? do
    it 'allows administrator' do
      expect(subject).to permit(admin_context, macro)
    end
    it 'allows standard agent' do
      expect(subject).to permit(agent_context, macro)
    end
    it 'allows custom role with permission' do
      expect(subject).to permit(custom_role_context, macro)
    end
    it 'denies custom role WITHOUT permission' do
      expect(subject).not_to permit(restricted_context, macro)
    end
  end

  permissions :update? do
    context 'when author' do
      let(:own_macro) { create(:macro, account: account, created_by: restricted_user) }
      
      it 'allows administrator' do
        admin_macro = create(:macro, account: account, created_by: admin_user)
        expect(subject).to permit(admin_context, admin_macro)
      end
      
      it 'allows standard agent if author' do
        # agent_user is author of 'macro'
        expect(subject).to permit(agent_context, macro)
      end

      it 'allows custom role with permission if author' do
        m = create(:macro, account: account, created_by: custom_role_user)
        expect(subject).to permit(custom_role_context, m)
      end

      it 'denies custom role WITHOUT permission even if author' do
        expect(subject).not_to permit(restricted_context, own_macro)
      end
    end

    context 'when not author' do
      it 'denies standard agent' do
        expect(subject).not_to permit(agent_context, create(:macro, account: account, created_by: admin_user))
      end
    end
  end

  permissions :destroy? do
    let(:own_macro) { create(:macro, account: account, created_by: restricted_user) }
    
    it 'denies custom role WITHOUT permission even if author' do
      expect(subject).not_to permit(restricted_context, own_macro)
    end
    
    it 'allows custom role with permission if author' do
      m = create(:macro, account: account, created_by: custom_role_user)
      expect(subject).to permit(custom_role_context, m)
    end
  end
end
