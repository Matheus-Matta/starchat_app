require 'rails_helper'

RSpec.describe Whatsapp::Providers::YcloudService do
  subject(:service) { described_class.new(whatsapp_channel: channel) }

  let(:provider_config) do
    {
      'api_key' => 'ycloud-key',
      'waba_id' => 'waba-123',
      'phone_number_id' => 'phone-123',
      'webhook_secret' => 'webhook-secret'
    }
  end
  let(:account) do
    create(:account).tap { |record| record.enable_features!(:channel_ycloud) }
  end
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'ycloud',
      provider_config: provider_config,
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:conversation) { create(:conversation, inbox: channel.inbox) }
  let(:message) do
    create(
      :message,
      conversation: conversation,
      inbox: channel.inbox,
      message_type: :outgoing,
      content: 'Hello from YCloud'
    )
  end
  let(:headers) { { 'Content-Type' => 'application/json' } }

  describe '#send_message' do
    it 'sends text with an external ID and stores the YCloud message ID' do
      request = stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
                .with(
                  headers: { 'X-API-Key' => 'ycloud-key' },
                  body: hash_including(
                    from: channel.phone_number,
                    to: '+5511999999999',
                    type: 'text',
                    text: { body: message.content },
                    externalId: message.id.to_s
                  )
                )
                .to_return(status: 200, body: { id: 'yc-message-1', status: 'accepted' }.to_json, headers: headers)

      expect(service.send_message('+5511999999999', message)).to eq('yc-message-1')
      expect(request).to have_been_requested.once
      expect(message.reload.additional_attributes['ycloud_message_ids']).to eq(['yc-message-1'])
    end

    it 'uses recipient for a BSUID destination' do
      request = stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
                .with(body: hash_including(recipient: 'BR.123456789', type: 'text'))
                .to_return(status: 200, body: { id: 'yc-message-1' }.to_json, headers: headers)

      service.send_message('BR.123456789', message)

      expect(request).to have_been_requested.once
    end

    it 'sends every attachment and tracks each external message' do
      image = message.attachments.new(account: message.account, file_type: :image)
      image.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      document = message.attachments.new(account: message.account, file_type: :file)
      document.file.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'sample.pdf', content_type: 'application/pdf')
      message.save!

      request = stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
                .to_return(
                  { status: 200, body: { id: 'yc-image' }.to_json, headers: headers },
                  { status: 200, body: { id: 'yc-document' }.to_json, headers: headers }
                )

      expect(service.send_message('+5511999999999', message)).to eq('yc-image')
      expect(request).to have_been_requested.twice
      expect(message.reload.additional_attributes['ycloud_message_ids']).to eq(%w[yc-image yc-document])
    end

    it 'marks the message failed when every YCloud request fails' do
      stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
        .to_return(status: 400, body: { error: { message: 'Invalid recipient' } }.to_json, headers: headers)

      expect(service.send_message('+5511999999999', message)).to be_nil
      expect(message.reload).to be_failed
      expect(message.external_error).to eq('Invalid recipient')
    end

    it 'marks the message failed when only some attachments are accepted' do
      image = message.attachments.new(account: message.account, file_type: :image)
      image.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      document = message.attachments.new(account: message.account, file_type: :file)
      document.file.attach(io: Rails.root.join('spec/assets/sample.pdf').open, filename: 'sample.pdf', content_type: 'application/pdf')
      message.save!

      stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
        .to_return(
          { status: 200, body: { id: 'yc-image' }.to_json, headers: headers },
          { status: 400, body: { error: { message: 'Document rejected' } }.to_json, headers: headers }
        )

      expect(service.send_message('+5511999999999', message)).to eq('yc-image')
      expect(message.reload).to be_failed
      expect(message.external_error).to eq('Document rejected')
      expect(message.additional_attributes['ycloud_message_ids']).to eq(['yc-image'])
    end

    it 'marks the message failed when YCloud accepts without returning an ID' do
      stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
        .to_return(status: 200, body: { status: 'accepted' }.to_json, headers: headers)

      expect(service.send_message('+5511999999999', message)).to be_nil
      expect(message.reload).to be_failed
      expect(message.external_error).to eq('YCloud did not return a message ID')
    end
  end

  describe '#send_template' do
    it 'supports campaign sends without a Message record' do
      request = stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
                .with(body: hash_including(type: 'template', externalId: nil))
                .to_return(status: 200, body: { id: 'yc-template' }.to_json, headers: headers)

      result = service.send_template(
        '+5511999999999',
        { name: 'order_update', lang_code: 'pt_BR', parameters: [] },
        nil
      )

      expect(result).to eq('yc-template')
      expect(request).to have_been_requested.once
    end
  end

  describe '#validate_provider_config?' do
    it 'validates the configured WABA and phone number' do
      request = stub_request(
        :get,
        "https://api.ycloud.com/v2/whatsapp/phoneNumbers/waba-123/#{CGI.escape(channel.phone_number)}"
      ).with(headers: { 'X-API-Key' => 'ycloud-key' }).to_return(status: 200)

      expect(service.validate_provider_config?).to be(true)
      expect(request).to have_been_requested.once
    end

    it 'does not call YCloud when required configuration is missing' do
      channel.provider_config = provider_config.except('webhook_secret')

      expect(service.validate_provider_config?).to be(false)
      expect(a_request(:get, /api\.ycloud\.com/)).not_to have_been_made
    end

    it 'does not require a Meta phone number ID' do
      channel.provider_config = provider_config.except('phone_number_id')
      stub_request(
        :get,
        "https://api.ycloud.com/v2/whatsapp/phoneNumbers/waba-123/#{CGI.escape(channel.phone_number)}"
      ).to_return(status: 200)

      expect(service.validate_provider_config?).to be(true)
    end
  end

  describe '#sync_templates' do
    it 'preserves cached templates when YCloud is temporarily unavailable' do
      existing_templates = [{ 'name' => 'existing_template' }]
      channel.update_columns(message_templates: existing_templates, message_templates_last_updated: 1.day.ago)
      previous_update = channel.message_templates_last_updated
      stub_request(:get, 'https://api.ycloud.com/v2/whatsapp/templates')
        .with(query: hash_including('filter.wabaId' => 'waba-123'))
        .to_return(status: 503)

      expect(service.sync_templates).to be(false)
      expect(channel.reload.message_templates).to eq(existing_templates)
      expect(channel.message_templates_last_updated).to be_within(1.second).of(previous_update)
    end

    it 'preserves cached templates when YCloud returns an invalid payload' do
      existing_templates = [{ 'name' => 'existing_template' }]
      channel.update_columns(message_templates: existing_templates, message_templates_last_updated: 1.day.ago)
      stub_request(:get, 'https://api.ycloud.com/v2/whatsapp/templates')
        .with(query: hash_including('filter.wabaId' => 'waba-123'))
        .to_return(status: 200, body: { unexpected: true }.to_json, headers: headers)

      expect(service.sync_templates).to be(false)
      expect(channel.reload.message_templates).to eq(existing_templates)
    end
  end
end
