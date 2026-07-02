require 'rails_helper'

RSpec.describe 'Reports API - WhatsApp Templates', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  let(:params) do
    { inbox_id: inbox.id, since: 1.day.ago.to_i.to_s, until: 1.day.from_now.to_i.to_s }
  end

  def create_template_message(name:, status: 'sent')
    create(:message,
           account: account, inbox: inbox, conversation: conversation,
           message_type: :template, status: status,
           additional_attributes: { 'template_params' => { 'name' => name, 'language' => 'pt_BR' } })
  end

  describe 'GET /api/v2/accounts/{account.id}/reports/whatsapp_templates' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/reports/whatsapp_templates", params: params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'is forbidden' do
        get "/api/v2/accounts/#{account.id}/reports/whatsapp_templates",
            params: params, headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as administrator' do
      before do
        create_template_message(name: 'welcome', status: 'read')
        create_template_message(name: 'welcome', status: 'delivered')
        create_template_message(name: 'reminder', status: 'sent')
      end

      it 'returns aggregated template analytics' do
        get "/api/v2/accounts/#{account.id}/reports/whatsapp_templates",
            params: params, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        data = response.parsed_body['data']
        expect(data.size).to eq(2)

        welcome = data.find { |r| r['template_name'] == 'welcome' }
        expect(welcome['total']).to eq(2)
        expect(welcome['delivered']).to eq(2)
        expect(welcome['read']).to eq(1)
      end

      it 'returns an error for a non-whatsapp inbox' do
        other_inbox = create(:inbox, account: account)
        get "/api/v2/accounts/#{account.id}/reports/whatsapp_templates",
            params: params.merge(inbox_id: other_inbox.id), headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Not a WhatsApp inbox')
      end

      it 'returns an error for a missing inbox' do
        get "/api/v2/accounts/#{account.id}/reports/whatsapp_templates",
            params: params.merge(inbox_id: 0), headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Inbox not found')
      end
    end
  end
end
