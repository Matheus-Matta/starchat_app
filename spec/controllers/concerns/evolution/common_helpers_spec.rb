require 'rails_helper'

RSpec.describe Evolution::CommonHelpers, type: :controller do # Using type: controller just for concern testing structure
  # Create a dummy class to include the module
  class DummyController
    include Evolution::CommonHelpers
  end

  let(:dummy) { DummyController.new }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:agent) { create(:user, account: account, role: :agent) }

  before do
    # Clear existing members to test fallback
    inbox.members.destroy_all
    allow(Notification).to receive(:create!).and_call_original
  end

  describe '#create_incoming_call_notification' do
    let(:from_number) { '5511988887777' }

    context 'when inbox has members assigned' do
      before do
        inbox.add_members([agent.id])
        inbox.reload
      end

      it 'sends notification ONLY to members' do
        expect {
          dummy.create_incoming_call_notification(inbox, from_number)
        }.to change(Notification, :count).by(1)

        notification = Notification.last
        expect(notification.user).to eq(agent)
      end

      it 'does not send to admins who are not members' do
        dummy.create_incoming_call_notification(inbox, from_number)
        expect(Notification.where(user: admin, notification_type: 'incoming_call')).not_to exist
      end
    end

    context 'when inbox has NO members assigned' do
      it 'falls back to sending notification to administrators' do
        expect {
          dummy.create_incoming_call_notification(inbox, from_number)
        }.to change(Notification, :count).by(1) # Assumption: 1 admin created in setup

        notification = Notification.last
        expect(notification.user).to eq(admin)
      end
    end

    context 'deduplication' do
      before do
        inbox.add_members([agent.id])
        inbox.reload
      end

      it 'does not create duplicate notification within window' do
        # First call
        dummy.create_incoming_call_notification(inbox, from_number)
        
        # Second call immediately after
        expect {
          dummy.create_incoming_call_notification(inbox, from_number)
        }.not_to change(Notification, :count)
      end

      it 'creates new notification after window expires' do
        # Create an old notification
        create(:notification, 
          notification_type: 'incoming_call', 
          account: account, 
          user: agent, 
          primary_actor: inbox, 
          meta: { from_number: from_number }, 
          created_at: 2.minutes.ago
        )

        expect {
          dummy.create_incoming_call_notification(inbox, from_number)
        }.to change(Notification, :count).by(1)
      end
    end
  end

  describe '#create_connection_change_notification' do
    let(:status) { 'open' }

    it 'uses shared logic and prioritizes members' do
      inbox.add_members([agent.id])
      inbox.reload
      
      expect {
        dummy.create_connection_change_notification(inbox, status)
      }.to change(Notification, :count).by(1)

      expect(Notification.last.user).to eq(agent)
    end
  end
end
