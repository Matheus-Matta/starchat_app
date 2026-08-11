require 'rails_helper'

RSpec.describe '', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /starchat/api/v1/accounts/{account.id}/limits' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/starchat/api/v1/accounts/#{account.id}/limits", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      before do
        InstallationConfig.find_or_initialize_by(name: 'DEPLOYMENT_ENV').update!(value: 'cloud')
      end

      context 'when it is an agent' do
        it 'returns unauthorized' do
          get "/starchat/api/v1/accounts/#{account.id}/limits",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['id']).to eq(account.id)
          expect(json_response['limits']).to eq(
            {
              'conversation' => {},
              'non_web_inboxes' => {},
              'agents' => {
                'allowed' => account.usage_limits[:agents],
                'consumed' => 2
              },
              'cosmos' => {
                'documents' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit },
                'responses' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit }
              }
            }
          )
        end
      end

      context 'when it is an admin' do
        before do
          create(:conversation, account: account)
          create(:channel_api, account: account)
          InstallationConfig.find_or_initialize_by(name: 'DEPLOYMENT_ENV').update!(value: 'cloud')
        end

        it 'returns account limits without enforcing a default plan' do
          get "/starchat/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expected_response = {
            'id' => account.id,
            'limits' => {
              'conversation' => {},
              'non_web_inboxes' => {},
              'agents' => {
                'allowed' => account.usage_limits[:agents],
                'consumed' => 2
              },
              'cosmos' => {
                'documents' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit },
                'responses' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit }
              }
            }
          }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_response)
        end

        it 'returns the same limits when plan attributes are present' do
          account.update!(custom_attributes: { plan_name: 'Startups' })
          get "/starchat/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expected_response = {
            'id' => account.id,
            'limits' => {
              'agents' => {
                'allowed' => account.usage_limits[:agents],
                'consumed' => account.users.count
              },
              'conversation' => {},
              'cosmos' => {
                'documents' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit },
                'responses' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit }
              },
              'non_web_inboxes' => {}
            }
          }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_response)
        end

        it 'returns limits when no plan is configured' do
          get "/starchat/api/v1/accounts/#{account.id}/limits",
              headers: admin.create_new_auth_token,
              as: :json

          expected_response = {
            'id' => account.id,
            'limits' => {
              'conversation' => {},
              'non_web_inboxes' => {},
              'agents' => {
                'allowed' => account.usage_limits[:agents],
                'consumed' => 2
              },
              'cosmos' => {
                'documents' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit },
                'responses' => { 'consumed' => 0, 'current_available' => StarchatsApp.max_limit, 'total_count' => StarchatsApp.max_limit }
              }
            }
          }
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_response)
        end
      end
    end
  end

  describe 'API token access' do
    before do
      allow(StarchatsApp).to receive(:starchats_cloud?).and_return(true)
      account.disable_features!('api_and_webhooks')
    end

    # api_and_webhooks_enabled? is unconditionally true here — every account is
    # enterprise, so there is no plan left that could withhold API access. The stored
    # flag is deliberately ignored.
    it 'allows token access even with the api_and_webhooks flag disabled' do
      get "/starchat/api/v1/accounts/#{account.id}/limits",
          headers: { api_access_token: admin.access_token.token },
          as: :json

      expect(response).to have_http_status(:success)
    end

    it 'allows session-authenticated requests' do
      get "/starchat/api/v1/accounts/#{account.id}/limits",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
    end
  end


  describe 'POST /starchat/api/v1/accounts/{account.id}/toggle_deletion' do
end


  describe 'POST /starchat/api/v1/accounts/{account.id}/toggle_deletion' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/starchat/api/v1/accounts/#{account.id}/toggle_deletion", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'when it is an agent' do
        it 'returns unauthorized' do
          post "/starchat/api/v1/accounts/#{account.id}/toggle_deletion",
               headers: agent.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end


      context 'when it is an admin' do
        before do
          # Create the installation config for cloud environment
          InstallationConfig.find_or_initialize_by(name: 'DEPLOYMENT_ENV').update!(value: 'cloud')
        end

        it 'marks the account for deletion when action is delete' do
          post "/starchat/api/v1/accounts/#{account.id}/toggle_deletion",
               headers: admin.create_new_auth_token,
               params: { action_type: 'delete' },
               as: :json

          expect(response).to have_http_status(:ok)
          expect(account.reload.custom_attributes['marked_for_deletion_at']).to be_present
          expect(account.custom_attributes['marked_for_deletion_reason']).to eq('manual_deletion')
        end

        it 'unmarks the account for deletion when action is undelete' do
          # First mark the account for deletion
          account.update!(
            custom_attributes: {
              'marked_for_deletion_at' => 7.days.from_now.iso8601,
              'marked_for_deletion_reason' => 'manual_deletion'
            }
          )

          post "/starchat/api/v1/accounts/#{account.id}/toggle_deletion",
               headers: admin.create_new_auth_token,
               params: { action_type: 'undelete' },
               as: :json

          expect(response).to have_http_status(:ok)
          expect(account.reload.custom_attributes['marked_for_deletion_at']).to be_nil
          expect(account.custom_attributes['marked_for_deletion_reason']).to be_nil
        end

        it 'returns error for invalid action' do
          post "/starchat/api/v1/accounts/#{account.id}/toggle_deletion",
               headers: admin.create_new_auth_token,
               params: { action_type: 'invalid' },
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['error']).to include('Invalid action_type')
        end

        it 'returns error when action parameter is missing' do
          post "/starchat/api/v1/accounts/#{account.id}/toggle_deletion",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['error']).to include('Invalid action_type')
        end
      end
    end
  end
end
