require 'rails_helper'

RSpec.describe RoomChannel do
  let!(:contact_inbox) { create(:contact_inbox) }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  before do
    stub_connection
  end

  it 'subscribes to a stream when pubsub_token is provided' do
    subscribe(pubsub_token: contact_inbox.pubsub_token)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(contact_inbox.pubsub_token)
  end

  it 'subscribes to a stream when pubsub_token is provided for user' do
    subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(user.pubsub_token)
    expect(subscription).to have_stream_for("account_#{account.id}")
  end
  describe 'presence synchronization' do
    let(:account) { create(:account) }
    let(:user) { create(:user) }
    let!(:account_user) { create(:account_user, account: account, user: user) }

    before do
      allow(OnlineStatusTracker).to receive(:set_status)
      allow(OnlineStatusTracker).to receive(:update_presence)
      stub_connection
    end

    context 'when user is offline in DB' do
      before do
        account_user.update!(availability: 'offline')
      end

      it 'syncs offline status to Redis' do
        subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
        expect(OnlineStatusTracker).to have_received(:set_status).with(account.id, user.id, 'offline').at_least(:once)
      end
    end

    context 'when user is online in DB' do
      before do
        account_user.update!(availability: 'online')
      end

      it 'syncs online status to Redis' do
        subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
        expect(OnlineStatusTracker).to have_received(:set_status).with(account.id, user.id, 'online').at_least(:once)
      end
    end

    context 'when user is busy in DB' do
      before do
        account_user.update!(availability: 'busy')
      end

      it 'syncs busy status to Redis' do
        subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
        expect(OnlineStatusTracker).to have_received(:set_status).with(account.id, user.id, 'busy').at_least(:once)
      end
    end
  end

  describe '#unsubscribed' do
    let(:account) { create(:account) }
    let(:user) { create(:user) }
    let!(:account_user) { create(:account_user, account: account, user: user) }

    before do
      allow(OnlineStatusTracker).to receive(:set_status)
      allow(OnlineStatusTracker).to receive(:update_presence)
      stub_connection
    end

    context 'when a User disconnects' do
      before { subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id) }

      it 'enqueues Starchat::LogUserOfflineJob with correct arguments after unsubscription' do
        expect {
          unsubscribe
        }.to have_enqueued_job(Starchat::LogUserOfflineJob)
          .with(user.id, account.id, 'connection_lost')
      end

      it 'enqueues Starchat::LogUserOfflineJob with a delay of PRESENCE_DURATION + 5 seconds' do
        freeze_time do
          expected_wait = ::OnlineStatusTracker::PRESENCE_DURATION + 5.seconds
          unsubscribe
          expect(Starchat::LogUserOfflineJob).to have_been_enqueued
            .at(Time.current + expected_wait)
        end
      end

      it 'enqueues PresenceBroadcastJob after unsubscription' do
        expect {
          unsubscribe
        }.to have_enqueued_job(PresenceBroadcastJob).with(account.id)
      end
    end

    context 'when a Contact disconnects (not a User)' do
      let(:contact_inbox) { create(:contact_inbox) }

      before { subscribe(pubsub_token: contact_inbox.pubsub_token) }

      it 'does NOT enqueue Starchat::LogUserOfflineJob' do
        expect {
          unsubscribe
        }.not_to have_enqueued_job(Starchat::LogUserOfflineJob)
      end
    end
  end
end
