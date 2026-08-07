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
  describe 'unread filter count invalidation' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:user) { create(:user, account: account, role: :agent) }
    let(:notifier) { instance_double(Conversations::UnreadCounts::UserFilterNotifier, perform: true) }

    before do
      allow(Conversations::UnreadCounts::UserFilterNotifier).to receive(:new).and_return(notifier)
    end

    it 'notifies when inbox access is added' do
      create(:inbox_member, inbox: inbox, user: user)

      expect(Conversations::UnreadCounts::UserFilterNotifier).to have_received(:new).with(account: account, user: user)
      expect(notifier).to have_received(:perform)
    end

    it 'notifies when inbox access is removed' do
      inbox_member = create(:inbox_member, inbox: inbox, user: user)
      expect(Conversations::UnreadCounts::UserFilterNotifier).to receive(:new).with(account: account, user: user).and_return(notifier)
      expect(notifier).to receive(:perform)

      inbox_member.destroy!
    end
  end
end
