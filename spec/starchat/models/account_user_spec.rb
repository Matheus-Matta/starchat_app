# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser, type: :model do
  describe 'associations' do
    # option and dependant nullify
    it { is_expected.to belong_to(:custom_role).optional }
  end

  describe '#permissions' do
    context 'when custom role is assigned' do
      it 'returns custom role permissions plus the :custom_role flag' do
        account     = create(:account)
        custom_role = create(:custom_role, account: account, permissions: %w[conversation_manage contact_manage])
        account_user = create(:account_user, account: account, custom_role: custom_role)

        expect(account_user.permissions).to eq(%w[conversation_manage contact_manage custom_role])
      end
    end

    context 'when no custom role is assigned' do
      it 'returns the default agent permissions' do
        account      = create(:account)
        account_user = create(:account_user, account: account)

        expect(account_user.permissions).to eq(%w[agent create_macro create_canned_response])
      end
    end

    context 'when the user is an administrator' do
      it 'returns ["administrator"] regardless of custom role' do
        account      = create(:account)
        account_user = create(:account_user, account: account, role: :administrator)

        expect(account_user.permissions).to eq(['administrator'])
      end
    end
  end

  describe '#permission?' do
    let(:account) { create(:account) }

    context 'when user is an administrator' do
      subject(:account_user) { create(:account_user, account: account, role: :administrator) }

      it 'returns true for any granular permission' do
        expect(account_user.permission?(:report_manage)).to be(true)
        expect(account_user.permission?(:create_macro)).to be(true)
        expect(account_user.permission?(:conversation_manage)).to be(true)
      end
    end

    context 'when user has a custom role' do
      let(:custom_role) { create(:custom_role, account: account, permissions: %w[report_manage contact_manage]) }
      subject(:account_user) { create(:account_user, account: account, custom_role: custom_role) }

      it 'returns true for permissions the custom role includes' do
        expect(account_user.permission?(:report_manage)).to be(true)
        expect(account_user.permission?(:contact_manage)).to be(true)
      end

      it 'returns false for permissions not in the custom role' do
        expect(account_user.permission?(:conversation_manage)).to be(false)
        expect(account_user.permission?(:create_macro)).to be(false)
      end
    end

    context 'when user is a regular agent without a custom role' do
      subject(:account_user) { create(:account_user, account: account) }

      it 'returns true for standard agent permissions' do
        expect(account_user.permission?(:create_macro)).to be(true)
        expect(account_user.permission?(:create_canned_response)).to be(true)
      end

      it 'returns false for permissions outside the default agent set' do
        expect(account_user.permission?(:report_manage)).to be(false)
        expect(account_user.permission?(:conversation_manage)).to be(false)
        expect(account_user.permission?(:contact_manage)).to be(false)
      end
    end
  end

  describe 'unread filter count invalidation' do
    it 'notifies when the assigned custom role changes' do
      account = create(:account)
      custom_role = create(:custom_role, account: account)
      account_user = create(:account_user, account: account)
      notifier = instance_double(Conversations::UnreadCounts::UserFilterNotifier, perform: true)
      allow(Conversations::UnreadCounts::UserFilterNotifier).to receive(:new).and_return(notifier)

      account_user.update!(custom_role: custom_role)

      expect(Conversations::UnreadCounts::UserFilterNotifier).to have_received(:new).with(
        account: account,
        user: account_user.user
      )
      expect(notifier).to have_received(:perform)
    end
  end

  describe 'audit log' do
    context 'when account user is created' do
      it 'has associated audit log created' do
        account_user = create(:account_user)
        account_user_audit_log = Audited::Audit.where(auditable: account_user, action: 'create').first
        expect(account_user_audit_log).to be_present
        expect(account_user_audit_log.associated).to eq(account_user.account)
      end
    end

    context 'when account user is updated' do
      it 'has associated audit log created' do
        account_user = create(:account_user)
        account_user.update!(availability: 'offline')
        account_user_audit_log = Audited::Audit.where(auditable_type: 'AccountUser', action: 'update').first
        expect(account_user_audit_log).to be_present
        expect(account_user_audit_log.associated).to eq(account_user.account)
        expect(account_user_audit_log.audited_changes).to eq('availability' => [0, 1])
      end
    end
  end
end
