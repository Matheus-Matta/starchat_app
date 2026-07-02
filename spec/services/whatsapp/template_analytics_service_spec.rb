require 'rails_helper'

describe Whatsapp::TemplateAnalyticsService do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  let(:since) { 1.day.ago.to_i }
  let(:until_date) { 1.day.from_now.to_i }

  subject(:result) do
    described_class.new(account: account, inbox_id: inbox.id, since: since, until_date: until_date).perform
  end

  def create_template_message(name:, language: 'pt_BR', status: 'sent', created_at: Time.current)
    create(:message,
           account: account,
           inbox: inbox,
           conversation: conversation,
           message_type: :template,
           status: status,
           created_at: created_at,
           additional_attributes: { 'template_params' => { 'name' => name, 'language' => language } })
  end

  describe '#perform' do
    context 'when there are no template messages' do
      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end

    context 'when template messages exist' do
      before do
        create_template_message(name: 'welcome', status: 'sent')
        create_template_message(name: 'welcome', status: 'delivered')
        create_template_message(name: 'welcome', status: 'read')
        create_template_message(name: 'welcome', status: 'failed')
      end

      it 'groups messages by template name' do
        expect(result.size).to eq(1)
        expect(result.first[:template_name]).to eq('welcome')
      end

      it 'counts total messages' do
        expect(result.first[:total]).to eq(4)
      end

      it 'counts sent (non-failed) messages' do
        expect(result.first[:sent]).to eq(3)
      end

      it 'counts delivered messages (delivered + read)' do
        expect(result.first[:delivered]).to eq(2)
      end

      it 'counts read messages' do
        expect(result.first[:read]).to eq(1)
      end

      it 'counts failed messages' do
        expect(result.first[:failed]).to eq(1)
      end

      it 'computes delivery rate over sent messages' do
        # delivered 2 / sent 3
        expect(result.first[:delivery_rate]).to eq(66.7)
      end

      it 'computes read rate over sent messages' do
        # read 1 / sent 3
        expect(result.first[:read_rate]).to eq(33.3)
      end
    end

    context 'when multiple templates exist' do
      before do
        create_template_message(name: 'welcome', status: 'read')
        create_template_message(name: 'welcome', status: 'read')
        create_template_message(name: 'reminder', status: 'sent')
      end

      it 'returns one row per template' do
        expect(result.map { |r| r[:template_name] }).to contain_exactly('welcome', 'reminder')
      end

      it 'orders rows by total descending' do
        expect(result.first[:template_name]).to eq('welcome')
      end
    end

    context 'when the same template has multiple languages' do
      before do
        create_template_message(name: 'welcome', language: 'pt_BR', status: 'sent')
        create_template_message(name: 'welcome', language: 'en_US', status: 'sent')
      end

      it 'groups separately by language' do
        expect(result.size).to eq(2)
        expect(result.map { |r| r[:language] }).to contain_exactly('pt_BR', 'en_US')
      end
    end

    context 'when messages fall outside the date range' do
      before do
        create_template_message(name: 'welcome', status: 'sent', created_at: 10.days.ago)
        create_template_message(name: 'welcome', status: 'sent', created_at: Time.current)
      end

      it 'only counts messages within the range' do
        expect(result.first[:total]).to eq(1)
      end
    end

    context 'when non-template messages exist' do
      before do
        create_template_message(name: 'welcome', status: 'sent')
        create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing)
        create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
      end

      it 'ignores non-template messages' do
        expect(result.size).to eq(1)
        expect(result.first[:total]).to eq(1)
      end
    end

    context 'when a template message has no name in template_params' do
      before do
        create_template_message(name: 'welcome', status: 'sent')
        # Bypass model validation to simulate legacy/malformed data lacking a template name
        message = build(:message,
                        account: account, inbox: inbox, conversation: conversation,
                        message_type: :template, status: :sent,
                        additional_attributes: { 'template_params' => { 'language' => 'pt_BR' } })
        message.save!(validate: false)
      end

      it 'excludes messages without a template name' do
        expect(result.size).to eq(1)
      end
    end

    context 'when messages belong to a different inbox' do
      let(:other_channel) do
        create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
      end
      let(:other_conversation) { create(:conversation, account: account, inbox: other_channel.inbox) }

      before do
        create_template_message(name: 'welcome', status: 'sent')
        create(:message,
               account: account, inbox: other_channel.inbox, conversation: other_conversation,
               message_type: :template, status: :sent,
               additional_attributes: { 'template_params' => { 'name' => 'other', 'language' => 'pt_BR' } })
      end

      it 'only counts messages for the requested inbox' do
        expect(result.size).to eq(1)
        expect(result.first[:template_name]).to eq('welcome')
      end
    end

    context 'when delivery rate would divide by zero' do
      before do
        create_template_message(name: 'welcome', status: 'failed')
      end

      it 'returns 0.0 instead of raising' do
        expect(result.first[:delivery_rate]).to eq(0.0)
        expect(result.first[:read_rate]).to eq(0.0)
      end
    end
  end
end
