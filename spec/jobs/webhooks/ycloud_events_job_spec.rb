require 'rails_helper'

RSpec.describe Webhooks::YcloudEventsJob do
  subject(:job) { described_class.new }

  let(:account) do
    create(:account).tap { |record| record.enable_features!(:channel_ycloud) }
  end
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'ycloud',
      provider_config: {
        'api_key' => 'ycloud-key',
        'waba_id' => 'waba-123',
        'phone_number_id' => 'phone-123',
        'webhook_secret' => 'secret'
      },
      sync_templates: false,
      validate_provider_config: false
    )
  end

  before do
    allow(Redis::Alfred).to receive(:get)
    allow(Redis::Alfred).to receive(:set).and_return(true)
  end

  it 'normalizes and processes inbound media before marking it as read' do
    incoming_service = instance_double(Whatsapp::IncomingMessageYcloudService, perform: true)
    provider_service = instance_double(Whatsapp::Providers::YcloudService, mark_message_as_read: true)
    payload = {
      'id' => 'evt-image',
      'type' => 'whatsapp.inbound_message.received',
      'whatsappInboundMessage' => {
        'id' => 'yc-inbound-1',
        'wamid' => 'wamid.inbound.1',
        'wabaId' => 'waba-123',
        'from' => '+5511888888888',
        'to' => channel.phone_number,
        'sendTime' => Time.current.iso8601,
        'type' => 'image',
        'customerProfile' => { 'name' => 'Jane', 'username' => 'jane_handle' },
        'image' => { 'id' => 'media-1', 'mime_type' => 'image/jpeg', 'caption' => 'Photo' }
      }
    }

    allow(Whatsapp::IncomingMessageYcloudService).to receive(:new).and_return(incoming_service)
    allow(channel).to receive(:provider_service).and_return(provider_service)
    allow(Channel::Whatsapp).to receive(:find_by).and_return(channel)

    job.perform(channel.id, payload)

    expect(Whatsapp::IncomingMessageYcloudService).to have_received(:new).with(
      inbox: channel.inbox,
      params: hash_including(
        'entry' => [hash_including(
          'changes' => [hash_including(
            'value' => hash_including(
              'contacts' => [
                hash_including(
                  'wa_id' => '5511888888888',
                  'profile' => hash_including('name' => 'Jane', 'username' => 'jane_handle')
                )
              ],
              'messages' => [hash_including(id: 'wamid.inbound.1', type: 'image')]
            )
          )]
        )]
      )
    )
    expect(provider_service).to have_received(:mark_message_as_read).with('yc-inbound-1')
  end

  it 'persists an inbound image using the signed link and original filename' do
    stub_request(:get, 'https://media.ycloud.com/signed/media-1')
      .with(headers: { 'X-API-Key' => 'ycloud-key' })
      .to_return(
        status: 200,
        body: Rails.root.join('spec/assets/avatar.png').binread,
        headers: { 'Content-Type' => 'image/png' }
      )
    stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/inboundMessages/yc-inbound-media/markAsRead')
      .to_return(status: 200)
    payload = {
      'id' => 'evt-image-real',
      'type' => 'whatsapp.inbound_message.received',
      'whatsappInboundMessage' => {
        'id' => 'yc-inbound-media',
        'wamid' => 'wamid.inbound.media',
        'wabaId' => 'waba-123',
        'from' => '+5511888888888',
        'fromUserId' => 'BR.123',
        'to' => channel.phone_number,
        'sendTime' => Time.current.iso8601,
        'type' => 'image',
        'image' => {
          'id' => 'media-1',
          'link' => 'https://media.ycloud.com/signed/media-1',
          'filename' => 'original-photo.png',
          'mime_type' => 'image/png',
          'caption' => 'Photo'
        }
      }
    }

    job.perform(channel.id, payload)

    message = channel.inbox.messages.find_by(source_id: 'wamid.inbound.media')
    expect(message.content).to eq('Photo')
    expect(message.attachments.first).to be_image
    expect(message.attachments.first.file.filename.to_s).to eq('original-photo.png')
  end

  it 'updates and protects delivery status from regression' do
    conversation = create(:conversation, inbox: channel.inbox)
    message = create(
      :message,
      conversation: conversation,
      inbox: channel.inbox,
      message_type: :outgoing,
      source_id: 'yc-outbound-1',
      additional_attributes: {
        'ycloud_delivery_statuses' => { 'yc-outbound-1' => 'read' },
        'ycloud_message_ids' => ['yc-outbound-1']
      }
    )
    payload = {
      'id' => 'evt-status',
      'type' => 'whatsapp.message.updated',
      'whatsappMessage' => {
        'id' => 'yc-outbound-1',
        'wamid' => 'wamid.outbound.1',
        'externalId' => message.id.to_s,
        'status' => 'delivered'
      }
    }

    job.perform(channel.id, payload)

    expect(message.reload).to be_read
    expect(message.additional_attributes['ycloud_wamids']).to eq('yc-outbound-1' => 'wamid.outbound.1')
  end

  it 'skips a duplicate event' do
    allow(Redis::Alfred).to receive(:get).and_return('processed')
    expect(Channel::Whatsapp).not_to receive(:find_by)

    job.perform(channel.id, 'id' => 'evt-duplicate')
  end

  it 'does not release a lock owned by another worker' do
    allow(Redis::Alfred).to receive(:set).and_return(false)
    allow(Redis::Alfred).to receive(:delete)

    expect { job.perform(channel.id, 'id' => 'evt-processing') }
      .to raise_error(CustomExceptions::YcloudWebhookDependencyNotReady)
    expect(Redis::Alfred).not_to have_received(:delete)
  end

  it 'releases an event when its local message is not available yet' do
    allow(Redis::Alfred).to receive(:delete)
    payload = {
      'id' => 'evt-status-race',
      'type' => 'whatsapp.message.updated',
      'whatsappMessage' => {
        'id' => 'yc-outbound-race',
        'externalId' => '999999',
        'status' => 'sent'
      }
    }

    expect { job.perform(channel.id, payload) }
      .to raise_error(CustomExceptions::YcloudWebhookDependencyNotReady)
    expect(Redis::Alfred).to have_received(:delete).with('ycloud:webhook:event:evt-status-race')
  end

  it 'marks a campaign contact sent only after a real YCloud status' do
    conversation = create(:conversation, inbox: channel.inbox)
    campaign = create(:campaign, account: channel.account, inbox: channel.inbox)
    campaign_contact = campaign.campaign_contacts.create!(contact: conversation.contact, status: :pending)
    message = create(
      :message,
      conversation: conversation,
      inbox: channel.inbox,
      message_type: :template,
      additional_attributes: {
        'campaign_contact_id' => campaign_contact.id,
        'ycloud_delivery_statuses' => { 'yc-campaign-1' => 'sent' }
      }
    )
    payload = {
      'id' => 'evt-campaign-status',
      'type' => 'whatsapp.message.updated',
      'whatsappMessage' => {
        'id' => 'yc-campaign-1',
        'externalId' => message.id.to_s,
        'status' => 'delivered'
      }
    }

    job.perform(channel.id, payload)

    expect(campaign_contact.reload).to be_sent
    expect(campaign_contact.sent_at).to be_present
  end

  it 'marks a message and campaign contact failed when one attachment fails' do
    conversation = create(:conversation, inbox: channel.inbox)
    campaign = create(:campaign, account: channel.account, inbox: channel.inbox)
    campaign_contact = campaign.campaign_contacts.create!(contact: conversation.contact, status: :pending)
    message = create(
      :message,
      conversation: conversation,
      inbox: channel.inbox,
      message_type: :outgoing,
      additional_attributes: {
        'campaign_contact_id' => campaign_contact.id,
        'ycloud_delivery_statuses' => {
          'yc-attachment-1' => 'delivered',
          'yc-attachment-2' => 'sent'
        }
      }
    )
    payload = {
      'id' => 'evt-partial-failure',
      'type' => 'whatsapp.message.updated',
      'whatsappMessage' => {
        'id' => 'yc-attachment-2',
        'externalId' => "#{message.id}:2",
        'status' => 'failed',
        'errorMessage' => 'Document rejected'
      }
    }

    job.perform(channel.id, payload)

    expect(message.reload).to be_failed
    expect(message.external_error).to include('Document rejected')
    expect(campaign_contact.reload).to be_failed
  end

  it 'rejects group messages instead of adding them to a private conversation' do
    payload = {
      'id' => 'evt-group',
      'type' => 'whatsapp.inbound_message.received',
      'whatsappInboundMessage' => {
        'id' => 'yc-group-1',
        'groupId' => 'group-123',
        'from' => '+5511888888888',
        'to' => channel.phone_number,
        'type' => 'text',
        'text' => { 'body' => 'Group message' }
      }
    }

    expect { job.perform(channel.id, payload) }.not_to change(channel.inbox.messages, :count)
  end

  it 'does not process events after YCloud is disabled for the account' do
    channel
    account.disable_features!(:channel_ycloud)
    payload = {
      'id' => 'evt-disabled',
      'type' => 'whatsapp.inbound_message.received',
      'whatsappInboundMessage' => {
        'id' => 'yc-disabled',
        'from' => '+5511888888888',
        'to' => channel.phone_number,
        'type' => 'text',
        'text' => { 'body' => 'Should not be processed' }
      }
    }

    expect { job.perform(channel.id, payload) }.not_to change(channel.inbox.messages, :count)
  end

  it 'persists an outgoing echo without dispatching it again' do
    payload = {
      'id' => 'evt-echo',
      'type' => 'whatsapp.smb.message.echoes',
      'whatsappMessage' => {
        'id' => 'yc-echo-1',
        'wamid' => 'wamid.echo.1',
        'wabaId' => 'waba-123',
        'from' => channel.phone_number,
        'to' => '+5511777777777',
        'toUserId' => 'BR.456',
        'sendTime' => Time.current.iso8601,
        'type' => 'text',
        'text' => { 'body' => 'Sent from WhatsApp Business' }
      }
    }

    job.perform(channel.id, payload)

    message = channel.inbox.messages.find_by(source_id: 'wamid.echo.1')
    expect(message).to be_outgoing
    expect(message).to be_delivered
    expect(message.content_attributes['external_echo']).to be(true)
  end
end
