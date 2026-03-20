require 'rails_helper'

RSpec.describe 'Monitoring API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v2/accounts/:account_id/monitoring' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/monitoring"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as agent' do
      it 'returns forbidden' do
        get "/api/v2/accounts/#{account.id}/monitoring",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      let(:builder_instance) { instance_double(Monitoring::OperationalSnapshotBuilder, build: builder_payload) }
      let(:builder_payload) do
        {
          summary: { total_inboxes: 0, online_inboxes: 0, warning_inboxes: 0, offline_inboxes: 0,
                     total_agents: 0, agents_available: 0, agents_busy: 0, agents_offline: 0,
                     total_active_conversations: 0 },
          inboxes: [],
          agents: []
        }
      end

      before do
        allow(Monitoring::OperationalSnapshotBuilder).to receive(:new).and_return(builder_instance)
      end

      it 'responds with snapshot data' do
        get "/api/v2/accounts/#{account.id}/monitoring",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(Monitoring::OperationalSnapshotBuilder).to have_received(:new).with(account: account)
        expect(response.parsed_body['summary']['total_inboxes']).to eq(0)
      end
    end
  end
end
