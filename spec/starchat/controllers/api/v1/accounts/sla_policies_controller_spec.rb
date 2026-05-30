require 'rails_helper'

RSpec.describe 'SLA Policies API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    create(:sla_policy, account: account, name: 'SLA 1')
  end

  describe 'GET #index' do
    context 'authenticated admin' do
      it 'lists all SLA policies for the account' do
        get "/api/v1/accounts/#{account.id}/sla_policies",
            headers: admin.create_new_auth_token
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['payload'][0]).to include('name' => 'SLA 1')
      end
    end

    context 'authenticated agent' do
      it 'lists SLA policies for the account' do
        get "/api/v1/accounts/#{account.id}/sla_policies",
            headers: agent.create_new_auth_token
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['payload'][0]).to include('name' => 'SLA 1')
      end
    end

    context 'unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/sla_policies"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    let(:sla_policy) { create(:sla_policy, account: account) }

    context 'authenticated admin' do
      it 'shows the SLA policy' do
        get "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}",
            headers: admin.create_new_auth_token
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['payload']).to include('name' => sla_policy.name)
      end
    end

    context 'authenticated agent' do
      it 'shows the SLA policy details' do
        get "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}",
            headers: agent.create_new_auth_token
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['payload']).to include('name' => sla_policy.name)
      end
    end

    context 'unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      { sla_policy: { name: 'SLA 2',
                      description: 'SLA for premium users',
                      first_response_time_threshold: 1000,
                      next_response_time_threshold: 2000,
                      resolution_time_threshold: 3000,
                      only_during_business_hours: false } }
    end

    context 'authenticated admin' do
      it 'creates a new SLA policy' do
        expect do
          post "/api/v1/accounts/#{account.id}/sla_policies", params: valid_params,
                                                              headers: admin.create_new_auth_token
        end.to change(SlaPolicy, :count).by(1)
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['payload']).to include('name' => 'SLA 2')
      end
    end

    context 'authenticated agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/sla_policies",
             params: valid_params,
             headers: agent.create_new_auth_token,
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/sla_policies"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #update' do
    let(:sla_policy) { create(:sla_policy, account: account) }

    context 'authenticated admin' do
      it 'updates the SLA policy' do
        put "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}",
            params: { sla_policy: { name: 'SLA 2' } },
            headers: admin.create_new_auth_token
        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body['payload']).to include('name' => 'SLA 2')
      end
    end

    context 'authenticated agent' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}",
            params: { sla_policy: { name: 'SLA 2' } },
            headers: agent.create_new_auth_token,
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:sla_policy) { create(:sla_policy, account: account) }

    context 'authenticated admin' do
      it 'deletes the SLA policy' do
        delete "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}",
               headers: admin.create_new_auth_token
        expect(response).to have_http_status(:success)
        expect(SlaPolicy.count).to eq(1)
      end
    end

    context 'authenticated agent' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}",
               headers: agent.create_new_auth_token,
               as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/sla_policies/#{sla_policy.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
