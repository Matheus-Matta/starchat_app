require 'rails_helper'

describe Contacts::ContactableInboxesService do
  before do
    stub_request(:post, /graph.facebook.com/)
  end

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, email: 'contact@example.com', phone_number: '+2320000') }
  let!(:twilio_sms) { create(:channel_twilio_sms, account: account) }
  let!(:twilio_sms_inbox) { create(:inbox, channel: twilio_sms, account: account) }
  let!(:twilio_whatsapp) { create(:channel_twilio_sms, medium: :whatsapp, account: account) }
  let!(:twilio_whatsapp_inbox) { create(:inbox, channel: twilio_whatsapp, account: account) }
  let!(:email_channel) { create(:channel_email, account: account) }
  let!(:email_inbox) { create(:inbox, channel: email_channel, account: account) }
  let!(:api_channel) { create(:channel_api, account: account) }
  let!(:api_inbox) { create(:inbox, channel: api_channel, account: account) }
  let!(:website_inbox) { create(:inbox, channel: create(:channel_widget, account: account), account: account) }
  let!(:sms_inbox) { create(:inbox, channel: create(:channel_sms, account: account), account: account) }

  describe '#get (default mode - all contactable)' do
    it 'returns all contactable inboxes for the contact' do
      contactable_inboxes = described_class.new(contact: contact).get

      expect(contactable_inboxes).to include({ source_id: contact.phone_number, inbox: twilio_sms_inbox })
      expect(contactable_inboxes).to include({ source_id: "whatsapp:#{contact.phone_number}", inbox: twilio_whatsapp_inbox })
      expect(contactable_inboxes).to include({ source_id: contact.email, inbox: email_inbox })
      expect(contactable_inboxes).to include({ source_id: contact.phone_number, inbox: sms_inbox })
    end

    it 'does not return non contactable inboxes for the contact' do
      facebook_channel = create(:channel_facebook_page, account: account)
      facebook_inbox = create(:inbox, channel: facebook_channel, account: account)
      twitter_channel = create(:channel_twitter_profile, account: account)
      twitter_inbox = create(:inbox, channel: twitter_channel, account: account)

      contactable_inboxes = described_class.new(contact: contact).get

      expect(contactable_inboxes.pluck(:inbox)).not_to include(website_inbox)
      expect(contactable_inboxes.pluck(:inbox)).not_to include(facebook_inbox)
      expect(contactable_inboxes.pluck(:inbox)).not_to include(twitter_inbox)
    end

    context 'when api inbox is available' do
      it 'returns existing source id if contact inbox exists' do
        contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact)

        contactable_inboxes = described_class.new(contact: contact).get
        expect(contactable_inboxes).to include({ source_id: contact_inbox.source_id, inbox: api_inbox })
      end

      it 'generates new UUID if no ContactInbox exists (default mode)' do
        contactable_inboxes = described_class.new(contact: contact).get
        api_result = contactable_inboxes.find { |ci| ci[:inbox] == api_inbox }
        
        expect(api_result).to be_present
        expect(api_result[:source_id]).to be_present
        expect(api_result[:source_id]).to match(/[a-f0-9-]{36}/) # UUID format
      end
    end

    context 'when website inbox is available' do
      it 'returns existing source id if contact inbox exists without any conversations' do
        contact_inbox = create(:contact_inbox, inbox: website_inbox, contact: contact)

        contactable_inboxes = described_class.new(contact: contact).get
        expect(contactable_inboxes).to include({ source_id: contact_inbox.source_id, inbox: website_inbox })
      end

      it 'does not return existing source id if contact inbox exists with conversations' do
        contact_inbox = create(:contact_inbox, inbox: website_inbox, contact: contact)
        create(:conversation, contact: contact, inbox: website_inbox, contact_inbox: contact_inbox)

        contactable_inboxes = described_class.new(contact: contact).get
        expect(contactable_inboxes.pluck(:inbox)).not_to include(website_inbox)
      end
    end
  end

  describe '#get with only_existing: true' do
    context 'when contact has ContactInbox vinculado' do
      it 'returns all inboxes with existing ContactInbox even without conversations' do
        # Inboxes com ContactInbox e conversa
        twilio_sms_contact_inbox = create(:contact_inbox, inbox: twilio_sms_inbox, contact: contact, source_id: contact.phone_number)
        create(:conversation, contact: contact, inbox: twilio_sms_inbox, contact_inbox: twilio_sms_contact_inbox)
        
        # Inbox com ContactInbox mas SEM conversa (Vínculo "fantasma" agora é válido para exibição)
        create(:contact_inbox, inbox: email_inbox, contact: contact, source_id: contact.email)

        contactable_inboxes = described_class.new(contact: contact, only_existing: true).get

        # Deve retornar ambas
        expect(contactable_inboxes).to include({ source_id: twilio_sms_contact_inbox.source_id, inbox: twilio_sms_inbox })
        expect(contactable_inboxes.pluck(:inbox)).to include(email_inbox)
        expect(contactable_inboxes.length).to eq(2)
      end
    end

    context 'when contact has no ContactInbox vinculado' do
      it 'returns empty array even if contact has email and phone' do
        contactable_inboxes = described_class.new(contact: contact, only_existing: true).get

        expect(contactable_inboxes).to be_empty
      end
    end
  end

  describe 'Twilio alternate mediums' do
    let!(:twilio_alternate) { create(:channel_twilio_sms, account: account) }
    let!(:twilio_alternate_inbox) { create(:inbox, channel: twilio_alternate, account: account, name: 'Voice Inbox') }

    it 'returns inbox even if medium is not whatsapp (catch-all)' do
      contactable_inboxes = described_class.new(contact: contact).get
      expect(contactable_inboxes).to include({ source_id: contact.phone_number, inbox: twilio_alternate_inbox })
    end
  end
end
