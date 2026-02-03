require 'rails_helper'

RSpec.describe Evolution::IncomingMessageService do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account, name: 'Evolution Inbox') }
  let!(:contact) { create(:contact, account: account, phone_number: '+5521966621486') }
  let!(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: '5521966621486') }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact) }

  before do
    allow(Evolution::ConversationEnsurer).to receive(:ensure!).and_return(conversation)
    allow(inbox.channel).to receive(:is_a?).with(Channel::Evolution).and_return(true)

    # Mocking ensure_contact_from_message! to return our objects
    allow_any_instance_of(described_class).to receive(:ensure_contact_from_message!) do |instance|
      instance.instance_variable_set(:@contact, contact)
      instance.instance_variable_set(:@contact_inbox, contact_inbox)
    end
  end

  describe '#perform' do
    context 'when receiving a sticker message' do
      let(:payload) do
        {
          'key' => { 'remoteJid' => '5521966621486@s.whatsapp.net', 'fromMe' => false, 'id' => 'S1' },
          'message' => {
            'stickerMessage' => {
              'url' => 'https://web.whatsapp.net',
              'mimetype' => 'image/webp',
              'directPath' => '/v/t62.15575-24/test.enc',
              'mediaKey' => 'S0VZQkFTRTY0'
            }
          }
        }
      end

      it 'creates a message with content_type sticker' do
        allow_any_instance_of(described_class).to receive(:download_for_whatsapp_enc).and_return(
          ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new('fake data'), filename: 's.webp', content_type: 'image/webp'
          )
        )

        expect do
          described_class.new(inbox: inbox, processed: payload).perform
        end.to change { Message.where(content_type: 'sticker').count }.by(1)

        message = Message.where(content_type: 'sticker').last
        expect(message.attachments.count).to eq(1)
      end

      it 'uses the normalized mmg.whatsapp.net URL when url is invalid' do
        service = described_class.new(inbox: inbox, processed: payload)

        expect(service).to receive(:download_for_whatsapp_enc).with(
          hash_including(url: 'https://mmg.whatsapp.net/v/t62.15575-24/test.enc')
        ).and_return(
          ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new('data'), filename: 's.webp', content_type: 'image/webp'
          )
        )

        service.perform
      end
    end

    context 'when receiving a text message' do
      let(:text_payload) do
        {
          'key' => { 'remoteJid' => '5521966621486@s.whatsapp.net', 'fromMe' => false, 'id' => 'T1' },
          'message' => { 'conversation' => 'Olá!' }
        }
      end

      it 'creates a text message' do
        expect do
          described_class.new(inbox: inbox, processed: text_payload).perform
        end.to change { Message.where(message_type: :incoming).count }.by(1)

        message = Message.where(message_type: :incoming).last
        expect(message.content).to eq('Olá!')
      end
    end
  end
end
