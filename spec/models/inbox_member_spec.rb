# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InboxMember do
  include ActiveJob::TestHelper

  describe '#DestroyAssociationAsyncJob' do
    let(:inbox_member) { create(:inbox_member) }

    # ref: https://github.com/chatwoot/chatwoot/issues/4616
    context 'when parent inbox is destroyed' do
      it 'enques and processes DestroyAssociationAsyncJob' do
        perform_enqueued_jobs do
          inbox_member.inbox.destroy!
        end
        expect { inbox_member.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'cache invalidation' do
    let(:inbox_member) { create(:inbox_member) }

    it 'invalidates inbox cache when an agent is added to an inbox' do
      new_user = create(:user, account: inbox_member.inbox.account)
      expect(inbox_member.inbox).to receive(:update_account_cache)
      create(:inbox_member, inbox: inbox_member.inbox, user: new_user)
    end

    it 'invalidates inbox cache when an agent is removed from an inbox' do
      expect(inbox_member.inbox).to receive(:update_account_cache)
      inbox_member.destroy!
    end
  end

  describe 'WS event dispatch' do
    let(:inbox_member) { create(:inbox_member) }

    it 'dispatches inbox.member_added event when agent is added to inbox' do
      new_user = create(:user, account: inbox_member.inbox.account)
      dispatched = []
      allow(Rails.configuration.dispatcher).to receive(:dispatch) { |name, *args| dispatched << name }
      create(:inbox_member, inbox: inbox_member.inbox, user: new_user)
      expect(dispatched).to include(Events::Types::INBOX_MEMBER_ADDED)
    end

    it 'dispatches inbox.member_removed event when agent is removed from inbox' do
      dispatched = []
      allow(Rails.configuration.dispatcher).to receive(:dispatch) { |name, *args| dispatched << name }
      inbox_member.destroy!
      expect(dispatched).to include(Events::Types::INBOX_MEMBER_REMOVED)
end
end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:user) { create(:user) }
    let(:store) { Conversations::UnreadCounts::FilteredCountStore }

    before do
      account.enable_features!(:unread_count_for_filters)
    end

    it 'invalidates the user built-in filter version when inbox access is added' do
      expect do
        create(:inbox_member, inbox: inbox, user: user)
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates the user built-in filter version when inbox access is removed' do
      inbox_member = create(:inbox_member, inbox: inbox, user: user)

      expect do
        inbox_member.destroy!
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates the user built-in filter version when the parent inbox is removed' do
      create(:inbox_member, inbox: inbox, user: user)

      expect do
        perform_enqueued_jobs { inbox.destroy! }
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates administrator built-in filter versions when the parent inbox is removed' do
      admin = create(:user)
      create(:account_user, account: account, user: admin, role: :administrator)

      expect do
        perform_enqueued_jobs { inbox.destroy! }
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: admin.id) }.by(1)
    end
  end
end
