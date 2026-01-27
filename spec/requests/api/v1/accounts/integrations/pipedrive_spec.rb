require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Integrations::Pipedrive', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, email: 'person@example.com') }
  let!(:hook) { create(:integrations_hook, account: account, app_id: 'pipedrive', settings: { 'api_token' => 'test_token', 'company_domain' => 'acme', 'pipedrive_url' => 'https://acme.pipedrive.com' }) }
  
  # Mock Pipedrive Client
  let(:client_instance) { instance_double(PipedriveClient) }

  before do
    allow(PipedriveClient).to receive(:new).and_return(client_instance)
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/pipedrive/deals' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/accounts/#{account.id}/integrations/pipedrive/deals"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns deals list successfully' do
        deals_data = {
          'success' => true,
          'data' => [
            { 'id' => 1, 'title' => 'Deal 1', 'value' => 1000, 'currency' => 'USD', 'status' => 'open' }
          ],
          'additional_data' => {
            'pagination' => { 'start' => 0, 'limit' => 15, 'more_items_in_collection' => false },
            'summary' => { 'total_count' => 1 }
          }
        }

        # Mock BrowseResourcesService calls PipedriveClient.deals
        allow(client_instance).to receive(:deals).and_return(deals_data)

        get "/api/v1/accounts/#{account.id}/integrations/pipedrive/deals", 
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json['payload'].length).to eq(1)
        expect(json['payload'][0]['title']).to eq('Deal 1')
        expect(json['meta']['total']).to eq(1)
      end

      it 'handles pipedrive api errors gracefully' do
        allow(client_instance).to receive(:deals).and_return(nil)
        
        get "/api/v1/accounts/#{account.id}/integrations/pipedrive/deals", 
            headers: admin.create_new_auth_token

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('API Connection Error')
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/pipedrive/activities' do
    it 'returns activities list' do
      activities_data = {
        'success' => true,
        'data' => [
          { 'id' => 10, 'subject' => 'Call', 'done' => false }
        ],
        'additional_data' => { 'pagination' => { 'limit' => 15 }, 'summary' => { 'total_count' => 1 } }
      }

      allow(client_instance).to receive(:activities).and_return(activities_data)

      get "/api/v1/accounts/#{account.id}/integrations/pipedrive/activities", 
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['payload'][0]['subject']).to eq('Call')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/pipedrive/customer_context' do
    it 'returns customer context when contact_id is provided' do
      # FetchCustomerContextService deve ser mockado ou testado indiretamente
      # Vamos testar a integração do controller
      
      context_data = {
        person_id: 123,
        deals: [],
        activities: []
      }
      
      # Mockando o Service específico para simplificar, já que queremos testar o controller
      service_double = instance_double(Crm::Pipedrive::FetchCustomerContextService)
      allow(Crm::Pipedrive::FetchCustomerContextService).to receive(:new).with(contact: contact).and_return(service_double)
      allow(service_double).to receive(:perform).and_return(context_data)

      get "/api/v1/accounts/#{account.id}/integrations/pipedrive/customer_context",
          params: { contact_id: contact.id },
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['person_id']).to eq(123)
    end
  end
end
