# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Cosmos::Preferences', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'GET /api/v1/accounts/{account.id}/cosmos/preferences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/cosmos/preferences",
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns cosmos config' do
        get "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
      end
    end

    context 'when it is an admin' do
      it 'returns cosmos config' do
        get "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/cosmos/preferences' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            params: { cosmos_models: { editor: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns forbidden' do
        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: agent.create_new_auth_token,
            params: { cosmos_models: { editor: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an admin' do
      it 'updates cosmos_models' do
        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: admin.create_new_auth_token,
            params: { cosmos_models: { editor: 'gpt-4.1-mini' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(account.reload.cosmos_models['editor']).to eq('gpt-4.1-mini')
      end

      it 'updates cosmos_features' do
        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: admin.create_new_auth_token,
            params: { cosmos_features: { editor: true } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        expect(account.reload.cosmos_features['editor']).to be true
      end

      it 'merges with existing cosmos_models' do
        account.update!(cosmos_models: { 'editor' => 'gpt-4.1-mini', 'assistant' => 'gpt-5.1' })

        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: admin.create_new_auth_token,
            params: { cosmos_models: { editor: 'gpt-4.1' } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        models = account.reload.cosmos_models
        expect(models['editor']).to eq('gpt-4.1')
        expect(models['assistant']).to eq('gpt-5.1') # Preserved
      end

      it 'merges with existing cosmos_features' do
        account.update!(cosmos_features: { 'editor' => true, 'assistant' => false })

        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: admin.create_new_auth_token,
            params: { cosmos_features: { editor: false } },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        features = account.reload.cosmos_features
        expect(features['editor']).to be false
        expect(features['assistant']).to be false # Preserved
      end

      it 'updates both models and features in single request' do
        put "/api/v1/accounts/#{account.id}/cosmos/preferences",
            headers: admin.create_new_auth_token,
            params: {
              cosmos_models: { editor: 'gpt-4.1-mini' },
              cosmos_features: { editor: true }
            },
            as: :json

        expect(response).to have_http_status(:success)
        expect(json_response).to have_key(:providers)
        expect(json_response).to have_key(:models)
        expect(json_response).to have_key(:features)
        account.reload
        expect(account.cosmos_models['editor']).to eq('gpt-4.1-mini')
        expect(account.cosmos_features['editor']).to be true
      end
    end
  end
end
