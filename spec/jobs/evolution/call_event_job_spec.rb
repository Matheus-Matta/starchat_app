require 'rails_helper'

RSpec.describe Evolution::CallEventJob, type: :job do
  include ActiveJob::TestHelper
  include Evolution::CommonHelpers

  let(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account, name: "WhatsApp Inbox") }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  
  before do
    allow(Notification).to receive(:create!).and_call_original
    allow(Rails.logger).to receive(:info)
  end

  describe '#perform' do
    context 'when event status is "offer"' do
      let(:event_data) do
        {
          'status' => 'offer',
          'from' => '5511999999999@s.whatsapp.net',
          'chatId' => '5511999999999@s.whatsapp.net'
        }
      end

      it 'logs the event' do
        described_class.perform_now(inbox.id, event_data)
        expect(Rails.logger).to have_received(:info).with(/Call Event \(Offer\): from=5511999999999@s.whatsapp.net/)
      end

      it 'triggers incoming call notification' do
        expect {
          described_class.perform_now(inbox.id, event_data)
        }.to change(Notification, :count) # Should clarify exact count in more detailed spec but this checks triggering
      end
    end

    context 'when event status is NOT "offer"' do
      let(:event_data) { { 'status' => 'ringing', 'from' => '123' } }

      it 'ignores the event and does not log info' do
        expect(Rails.logger).not_to receive(:info).with(/Call Event \(Offer\)/)
        expect {
          described_class.perform_now(inbox.id, event_data)
        }.not_to change(Notification, :count)
      end
    end

    context 'when inbox is invalid' do
      it 'returns early' do
        expect {
          described_class.perform_now(999999, {})
        }.not_to change(Notification, :count)
      end
    end
  end
end
