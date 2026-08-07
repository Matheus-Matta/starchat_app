require 'rails_helper'

RSpec.describe Evolution::MigrateToWhatsappService do
  let(:account) { create(:account) }
  let(:evolution_channel) { create(:channel_evolution, account: account, state: 'open') }
  let!(:inbox) { evolution_channel.inbox }
  let(:evolution_client) { instance_double(Evolution::Client) }

  let(:whatsapp_params) do
    {
      phone_number: '+1234567890',
      api_key: 'test_key',
      phone_number_id: '111',
      business_account_id: '222'
    }
  end

  before do
    allow(Evolution::Client).to receive(:new).and_return(evolution_client)
    allow(evolution_client).to receive(:logout_instance)
    allow(evolution_client).to receive(:delete_instance)

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('EVOLUTION_BASE_URL').and_return('http://evolution.test')
    allow(ENV).to receive(:fetch).with('AUTHENTICATION_API_KEY', nil).and_return('test-api-key')
  end

  subject(:service) { described_class.new(evolution_channel: evolution_channel, whatsapp_params: whatsapp_params) }

  context 'when the whatsapp credentials are valid and webhook setup succeeds' do
    before do
      stub_request(:get, 'https://graph.facebook.com/v14.0/222/message_templates?access_token=test_key')
        .to_return(status: 200, body: { data: [] }.to_json)

      setup_service = instance_double(Whatsapp::WebhookSetupService)
      allow(Whatsapp::WebhookSetupService).to receive(:new).and_return(setup_service)
      allow(setup_service).to receive(:perform)
    end

    it 'keeps the same inbox and repoints it to a new Channel::Whatsapp' do
      result = service.perform

      expect(result.inbox.id).to eq(inbox.id)
      expect(result.inbox.channel).to be_a(Channel::Whatsapp)
      expect(result.inbox.channel.phone_number).to eq('+1234567890')
      expect(result.needs_reauthorization).to be(false)
    end

    it 'disconnects and destroys the old Evolution instance' do
      expect(evolution_client).to receive(:logout_instance).with(evolution_channel.instance_name)
      expect(evolution_client).to receive(:delete_instance).with(evolution_channel.instance_name)

      service.perform

      expect(Channel::Evolution.exists?(evolution_channel.id)).to be(false)
    end

    it 'does not change the inbox id, preserving its conversations' do
      conversation = create(:conversation, account: account, inbox: inbox)

      service.perform

      expect(conversation.reload.inbox_id).to eq(inbox.id)
    end

    it 'preserves conversations, messages and contact_inboxes untouched by inbox_id' do
      conversation = create(:conversation, account: account, inbox: inbox)
      message = create(:message, account: account, inbox: inbox, conversation: conversation)
      contact_inbox = create(:contact_inbox, inbox: inbox, source_id: '5511999998888')

      expect { service.perform }
        .to not_change { conversation.reload.inbox_id }
        .and not_change { message.reload.inbox_id }
        .and not_change { contact_inbox.reload.attributes.slice('inbox_id', 'source_id') }
    end

    it 'persists the whatsapp cloud provider_config correctly' do
      result = service.perform

      expect(result.whatsapp_channel.provider).to eq('whatsapp_cloud')
      expect(result.whatsapp_channel.provider_config).to include(
        'api_key' => 'test_key',
        'phone_number_id' => '111',
        'business_account_id' => '222'
      )
    end

    it 'flips the inbox channel_type so downstream routing treats it as WhatsApp' do
      service.perform

      inbox.reload
      expect(inbox.channel_type).to eq('Channel::Whatsapp')
      expect(inbox.whatsapp?).to be(true)
      expect(inbox.evolution?).to be(false)
      expect(SendReplyJob::CHANNEL_SERVICES[inbox.channel_type]).to eq(Whatsapp::SendOnWhatsappService)
    end

    it 'changes the overall channel counts by exactly one' do
      expect { service.perform }
        .to change(Channel::Whatsapp, :count).by(1)
        .and change(Channel::Evolution, :count).by(-1)
    end

    it 'keeps a pre-existing contact_inbox valid under WhatsApp source_id rules after migration' do
      contact_inbox = create(:contact_inbox, inbox: inbox, source_id: '5511999998888')

      service.perform

      contact_inbox.reload
      expect(contact_inbox).to be_valid
      expect(contact_inbox.source_id).to eq('5511999998888')
    end
  end

  context 'when the whatsapp credentials are invalid' do
    before do
      stub_request(:get, 'https://graph.facebook.com/v14.0/222/message_templates?access_token=test_key')
        .to_return(status: 401)
    end

    it 'rolls back and leaves the Evolution channel untouched' do
      expect { service.perform }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Channel::Evolution.exists?(evolution_channel.id)).to be(true)
      expect(inbox.reload.channel).to eq(evolution_channel)
      expect(evolution_client).not_to have_received(:logout_instance)
    end
  end

  context 'when the new whatsapp channel ends up needing reauthorization' do
    before do
      stub_request(:get, 'https://graph.facebook.com/v14.0/222/message_templates?access_token=test_key')
        .to_return(status: 200, body: { data: [] }.to_json)

      # `after_commit :setup_webhooks` is disabled in test env (Channel::Whatsapp#should_auto_setup_webhooks?),
      # so we simulate a failed webhook registration directly via reauthorization_required?.
      allow_any_instance_of(Channel::Whatsapp).to receive(:reauthorization_required?).and_return(true) # rubocop:disable RSpec/AnyInstance
    end

    it 'keeps the old Evolution instance alive as a fallback instead of disconnecting it' do
      result = service.perform

      expect(result.needs_reauthorization).to be(true)
      expect(Channel::Evolution.exists?(evolution_channel.id)).to be(true)
      expect(evolution_client).not_to have_received(:logout_instance)
    end
  end
end
