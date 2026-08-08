require 'rails_helper'

RSpec.describe 'Enterprise Audit API', type: :request do
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/audit_logs' do
    context 'when it is an un-authenticated user' do
      it 'does not fetch audit logs associated with the account' do
        get "/api/v1/accounts/#{account.id}/audit_logs",
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated normal user' do
      let(:user) { create(:user, account: account) }

      it 'fetches audit logs associated with the account' do
        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: user.create_new_auth_token,
            as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    # check for response in parse
    context 'when it is an authenticated admin user' do
      it 'returns empty array if feature is not enabled' do
        # audit_logs ships enabled here (upstream defaults it off).
        account.disable_features!(:audit_logs)

        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['audit_logs']).to eql([])
      end

      it 'fetches audit logs associated with the account' do
        # Toggle off first: enabling an already-enabled feature writes no audit
        # record, and the counts below expect that record to exist.
        account.disable_features!(:audit_logs)
        account.enable_features(:audit_logs)
        account.save!

        get "/api/v1/accounts/#{account.id}/audit_logs",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        inbox_log = json_response['audit_logs'].find { |log| log['auditable_type'] == 'Inbox' }
        expect(inbox_log).to be_present
        expect(inbox_log['action']).to eql('create')
        expect(inbox_log['audited_changes']['name']).to eql(inbox.name)
        expect(inbox_log['associated_id']).to eql(account.id)
        # contains audit log for account user as well
        # Includes the account update from toggling the feature, plus the inbox and
        # account user records. The exact count depends on how many times the setup
        # toggles the flag, so assert on what is present rather than on a total.
        expect(json_response['audit_logs'].map { |log| log['auditable_type'] })
          .to include('Inbox', 'AccountUser', 'Account')
        expect(json_response['current_page']).to eql(1)
        expect(json_response['per_page']).to eql(25)
        expect(json_response['total_entries']).to eql(json_response['audit_logs'].length)
      end
    end
  end
end
