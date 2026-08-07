require 'rails_helper'

describe Whatsapp::OneoffCampaignService do
  let(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let!(:whatsapp_inbox) { whatsapp_channel.inbox }
  let(:label1) { create(:label, account: account) }
  let(:label2) { create(:label, account: account) }
  let!(:campaign) do
    create(:campaign, inbox: whatsapp_inbox, account: account,
                      audience: [{ type: 'Label', id: label1.id }, { type: 'Label', id: label2.id }],
                      template_params: template_params)
  end
  let(:template_params) do
    {
      'name' => 'ticket_status_updated',
      'namespace' => '23423423_2342423_324234234_2343224',
      'category' => 'UTILITY',
      'language' => 'en',
      'processed_params' => { 'body' => { 'name' => 'John', 'ticket_id' => '2332' } }
    }
  end

  before do
    # Stub HTTP requests to WhatsApp API
    stub_request(:post, /graph\.facebook\.com.*messages/)
      .to_return(status: 200, body: { messages: [{ id: 'message_id_123' }] }.to_json, headers: { 'Content-Type' => 'application/json' })

    # Ensure the service uses our mocked channel object by stubbing the whole delegation chain
    # Using allow_any_instance_of here because the service is instantiated within individual tests
    # and we need to mock the delegated channel method for proper test isolation
    allow_any_instance_of(described_class).to receive(:channel).and_return(whatsapp_channel)
  end

  describe '#perform' do
    before do
      # Enable WhatsApp campaigns feature flag for all tests
      account.enable_features!(:whatsapp_campaign)
    end

    context 'when campaign validation fails' do
      it 'raises error if campaign is completed' do
        campaign.completed!

        expect { described_class.new(campaign: campaign).perform }.to raise_error 'Completed Campaign'
      end

      it 'raises error when campaign is not a WhatsApp campaign' do
        sms_channel = create(:channel_sms, account: account)
        sms_inbox = create(:inbox, channel: sms_channel, account: account)
        invalid_campaign = create(:campaign, inbox: sms_inbox, account: account)

        expect { described_class.new(campaign: invalid_campaign).perform }
          .to raise_error "Invalid campaign #{invalid_campaign.id}"
      end

      it 'raises error when campaign is not oneoff' do
        allow(campaign).to receive(:one_off?).and_return(false)

        expect { described_class.new(campaign: campaign).perform }.to raise_error "Invalid campaign #{campaign.id}"
      end

      it 'raises error when the WhatsApp provider does not support campaigns' do
        whatsapp_channel.update!(provider: 'default')

        expect { described_class.new(campaign: campaign).perform }.to raise_error 'Unsupported WhatsApp provider'
      end

      it 'raises error when WhatsApp campaigns feature is not enabled' do
        account.disable_features!(:whatsapp_campaign)

        expect { described_class.new(campaign: campaign).perform }.to raise_error 'WhatsApp campaigns feature not enabled'
      end
    end

    context 'when campaign is valid' do
      it 'marks campaign as completed' do
        described_class.new(campaign: campaign).perform

        expect(campaign.reload.completed?).to be true
      end

      it 'marks the campaign completed after processing the audience' do
        contact = create(:contact, :with_phone_number, account: account)
        contact.update_labels([label1.title])

        expect(whatsapp_channel).to receive(:send_template) do
          expect(campaign.reload.completed?).to be false
        end

        described_class.new(campaign: campaign).perform

        expect(campaign.reload.completed?).to be true
      end

      it 'processes contacts with matching labels' do
        contact_with_label1, contact_with_label2, contact_with_both_labels =
          create_list(:contact, 3, :with_phone_number, account: account)
        contact_with_label1.update_labels([label1.title])
        contact_with_label2.update_labels([label2.title])
        contact_with_both_labels.update_labels([label1.title, label2.title])

        expect(whatsapp_channel).to receive(:send_template).exactly(3).times

        described_class.new(campaign: campaign).perform
      end

      it 'skips contacts without phone numbers' do
        contact_without_phone = create(:contact, account: account, phone_number: nil)
        contact_without_phone.update_labels([label1.title])

        expect(whatsapp_channel).not_to receive(:send_template)

        described_class.new(campaign: campaign).perform
      end

      it 'uses template processor service to process templates' do
        contact = create(:contact, :with_phone_number, account: account)
        contact.update_labels([label1.title])

        expect(Whatsapp::TemplateProcessorService).to receive(:new)
          .with(channel: whatsapp_channel, template_params: template_params)
          .and_call_original

        described_class.new(campaign: campaign).perform
      end

      it 'sends template message with correct parameters' do
        contact = create(:contact, :with_phone_number, account: account)
        contact.update_labels([label1.title])

        expect(whatsapp_channel).to receive(:send_template).with(
          contact.phone_number,
          hash_including(
            name: 'ticket_status_updated',
            namespace: '23423423_2342423_324234234_2343224',
            lang_code: 'en',
            parameters: array_including(
              hash_including(
                type: 'body',
                parameters: array_including(
                  hash_including(type: 'text', parameter_name: 'name', text: 'John'),
                  hash_including(type: 'text', parameter_name: 'ticket_id', text: '2332')
                )
              )
            )
          ),
          nil
        )

        described_class.new(campaign: campaign).perform
      end

      it 'processes liquid variables in template parameters' do
        contact = create(:contact, :with_phone_number, account: account, name: 'Jane Smith', email: 'jane@example.com')
        contact.update_labels([label1.title])

        campaign_with_liquid = create(:campaign, inbox: whatsapp_inbox, account: account,
                                                 audience: [{ type: 'Label', id: label1.id }],
                                                 template_params: {
                                                   'name' => 'ticket_status_updated',
                                                   'namespace' => '23423423_2342423_324234234_2343224',
                                                   'category' => 'UTILITY',
                                                   'language' => 'en',
                                                   'processed_params' => {
                                                     'body' => {
                                                       'name' => '{{contact.name}}',
                                                       'ticket_id' => '{{contact.email}}'
                                                     }
                                                   }
                                                 })

        contact_drop_name = ContactDrop.new(contact).name

        expect(whatsapp_channel).to receive(:send_template).with(
          contact.phone_number,
          hash_including(
            name: 'ticket_status_updated',
            namespace: '23423423_2342423_324234234_2343224',
            lang_code: 'en',
            parameters: array_including(
              hash_including(
                type: 'body',
                parameters: array_including(
                  hash_including(type: 'text', parameter_name: 'name', text: contact_drop_name),
                  hash_including(type: 'text', parameter_name: 'ticket_id', text: contact.email)
                )
              )
            )
          ),
          nil
        )

        described_class.new(campaign: campaign_with_liquid).perform
      end

      it 'skips contacts when liquid variables resolve to blank values' do
        contact = create(:contact, :with_phone_number, account: account, name: 'Jane', email: nil)
        contact.update_labels([label1.title])

        campaign_with_blank_liquid = create(:campaign, inbox: whatsapp_inbox, account: account,
                                                       audience: [{ type: 'Label', id: label1.id }],
                                                       template_params: {
                                                         'name' => 'test_template',
                                                         'namespace' => 'test_namespace',
                                                         'language' => 'en',
                                                         'processed_params' => {
                                                           'body' => {
                                                             'email' => '{{contact.email}}'
                                                           }
                                                         }
                                                       })

        expect(whatsapp_channel).not_to receive(:send_template)
        expect(Rails.logger).to receive(:info).with("Skipping contact #{contact.name} - liquid variables resolved to blank values")
        allow(Rails.logger).to receive(:info)

        described_class.new(campaign: campaign_with_blank_liquid).perform
      end
    end

    context 'when template_params is missing but campaign has a message' do
      let(:template_params) { nil }

      it 'falls back to sending a plain text message' do
        contact = create(:contact, :with_phone_number, account: account)
        contact.update_labels([label1.title])

        provider_service = instance_double(Whatsapp::Providers::WhatsappCloudService)
        allow(whatsapp_channel).to receive(:provider_service).and_return(provider_service)
        expect(provider_service).to receive(:send_plain_text).with(contact.phone_number, campaign.message).and_return(true)
        expect(whatsapp_channel).not_to receive(:send_template)

        described_class.new(campaign: campaign).perform

        campaign_contact = campaign.campaign_contacts.find_by(contact: contact)
        expect(campaign_contact.status).to eq('sent')
      end
    end

    context 'when send_template raises an error' do
      it 'logs error and continues processing remaining contacts' do
        contact_error, contact_success = create_list(:contact, 2, :with_phone_number, account: account)
        contact_error.update_labels([label1.title])
        contact_success.update_labels([label1.title])
        error_message = 'WhatsApp API error'

        allow(whatsapp_channel).to receive(:send_template).and_return(nil)

        expect(whatsapp_channel).to receive(:send_template).with(contact_error.phone_number, anything, nil).and_raise(StandardError, error_message)
        expect(whatsapp_channel).to receive(:send_template).with(contact_success.phone_number, anything, nil).once

        expect(Rails.logger).to receive(:error)
          .with("Failed to send WhatsApp template message to #{contact_error.phone_number}: #{error_message}")
        expect(Rails.logger).to receive(:error).with(/Backtrace:/)

        described_class.new(campaign: campaign).perform
        expect(campaign.reload.completed?).to be true
      end
    end

    context 'when registering campaign conversations' do
      let(:contact) { create(:contact, :with_phone_number, account: account) }

      before do
        account.enable_features!(:whatsapp_campaign)
        contact.update_labels([label1.title])
      end

      it 'creates a conversation for the contact after sending' do
        expect { described_class.new(campaign: campaign).perform }
          .to change { contact.conversations.count }.by(1)
      end

      it 'registers the template message in the new conversation' do
        described_class.new(campaign: campaign).perform
        conversation = contact.conversations.last
        expect(conversation.messages.where(message_type: :template)).to exist
      end

      it 'stores the source_id returned by the Meta API on the registered message' do
        described_class.new(campaign: campaign).perform
        message = contact.conversations.last.messages.where(message_type: :template).last
        expect(message.source_id).to eq('message_id_123')
      end

      it 'does not call send_template a second time when registering the message' do
        allow(whatsapp_channel).to receive(:send_template).and_call_original
        described_class.new(campaign: campaign).perform
        expect(whatsapp_channel).to have_received(:send_template).exactly(:once)
      end

      context 'when the contact already has an open conversation on the inbox' do
        let!(:contact_inbox) do
          contact.contact_inboxes.find_or_create_by!(inbox: whatsapp_inbox) do |ci|
            ci.source_id = contact.phone_number.to_s.delete('+')
          end
        end
        let!(:existing_conversation) do
          create(:conversation, contact: contact, inbox: whatsapp_inbox,
                                contact_inbox: contact_inbox, status: :open, account: account)
        end

        it 'does not create a new conversation' do
          expect { described_class.new(campaign: campaign).perform }
            .not_to change(contact.conversations, :count)
        end

        it 'registers the message in the existing conversation' do
          described_class.new(campaign: campaign).perform
          expect(existing_conversation.messages.reload.where(message_type: :template)).to exist
        end
      end

      context 'when lock_to_single_conversation is enabled' do
        before { whatsapp_inbox.update!(lock_to_single_conversation: true) }

        let!(:contact_inbox) do
          contact.contact_inboxes.find_or_create_by!(inbox: whatsapp_inbox) do |ci|
            ci.source_id = contact.phone_number.to_s.delete('+')
          end
        end
        let!(:resolved_conversation) do
          create(:conversation, contact: contact, inbox: whatsapp_inbox,
                                contact_inbox: contact_inbox, status: :resolved, account: account)
        end

        it 'reuses the existing resolved conversation instead of creating a new one' do
          expect { described_class.new(campaign: campaign).perform }
            .not_to change(contact.conversations, :count)
        end

        it 'registers the message in the resolved conversation' do
          described_class.new(campaign: campaign).perform
          expect(resolved_conversation.messages.reload.where(message_type: :template)).to exist
        end
      end

      context 'when lock_to_single_conversation is disabled and contact only has a resolved conversation' do
        let!(:contact_inbox) do
          contact.contact_inboxes.find_or_create_by!(inbox: whatsapp_inbox) do |ci|
            ci.source_id = contact.phone_number.to_s.delete('+')
          end
        end

        before do
          whatsapp_inbox.update!(lock_to_single_conversation: false)
          create(:conversation, contact: contact, inbox: whatsapp_inbox,
                                contact_inbox: contact_inbox, status: :resolved, account: account)
        end

        it 'creates a new open conversation' do
          expect { described_class.new(campaign: campaign).perform }
            .to change { contact.conversations.count }.by(1)
        end

        it 'sets the new conversation status to open' do
          described_class.new(campaign: campaign).perform
          expect(contact.conversations.order(:created_at).last.status).to eq('open')
        end
      end

      context 'when register_campaign_message raises an error' do
        before do
          allow_any_instance_of(described_class).to receive(:find_or_open_conversation).and_raise(StandardError, 'DB error')
        end

        it 'logs the error without affecting campaign_contact status' do
          expect(Rails.logger).to receive(:error)
            .with("Failed to register campaign message for contact #{contact.name}: DB error")
          described_class.new(campaign: campaign).perform
        end

        it 'still marks the campaign_contact as sent' do
          allow(Rails.logger).to receive(:error)
          described_class.new(campaign: campaign).perform
          campaign_contact = campaign.campaign_contacts.find_by(contact: contact)
          expect(campaign_contact.status).to eq('sent')
        end
      end
    end

    context 'with the YCloud provider' do
      before do
        account.enable_features!(:channel_ycloud)
        whatsapp_channel.update_columns(
          provider: 'ycloud',
          provider_config: {
            'api_key' => 'ycloud-key',
            'waba_id' => 'waba-123',
            'webhook_secret' => 'webhook-secret'
          }
        )
      end

      it 'registers a template message before sending and keeps the campaign contact pending for the webhook' do
        contact = create(:contact, :with_phone_number, account: account)
        contact.update_labels([label1.title])
        stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
          .to_return(
            status: 200,
            body: { id: 'yc-campaign-template', status: 'accepted' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        described_class.new(campaign: campaign).perform

        campaign_contact = campaign.campaign_contacts.find_by!(contact: contact)
        message = contact.conversations.last.messages.template.last
        expect(campaign_contact).to be_pending
        expect(message.source_id).to eq('yc-campaign-template')
        expect(message.additional_attributes['campaign_contact_id']).to eq(campaign_contact.id)
        expect(
          a_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
            .with(body: hash_including(externalId: message.id.to_s))
        ).to have_been_made.once
      end

      context 'when sending plain text' do
        let(:template_params) { nil }

        it 'creates a correlated outgoing message and waits for a status webhook' do
          contact = create(:contact, :with_phone_number, account: account)
          contact.update_labels([label1.title])
          stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
            .to_return(
              status: 200,
              body: { id: 'yc-campaign-text', status: 'accepted' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )

          described_class.new(campaign: campaign).perform

          campaign_contact = campaign.campaign_contacts.find_by!(contact: contact)
          message = contact.conversations.last.messages.outgoing.last
          expect(campaign_contact).to be_pending
          expect(message.source_id).to eq('yc-campaign-text')
          expect(message.additional_attributes['campaign_contact_id']).to eq(campaign_contact.id)
          expect(
            a_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
              .with(body: hash_including(externalId: message.id.to_s, type: 'text'))
          ).to have_been_made.once
        end

        it 'marks the campaign contact failed when YCloud rejects the message' do
          contact = create(:contact, :with_phone_number, account: account)
          contact.update_labels([label1.title])
          stub_request(:post, 'https://api.ycloud.com/v2/whatsapp/messages')
            .to_return(
              status: 400,
              body: { error: { message: 'Invalid recipient' } }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )

          described_class.new(campaign: campaign).perform

          campaign_contact = campaign.campaign_contacts.find_by!(contact: contact)
          expect(campaign_contact).to be_failed
          expect(campaign_contact.error_message).to eq('Invalid recipient')
        end
      end
    end
  end
end
