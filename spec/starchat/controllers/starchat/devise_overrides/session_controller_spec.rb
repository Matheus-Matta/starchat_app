require 'rails_helper'

RSpec.describe 'Starchat Audit API', type: :request do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, password: 'Password1!', account: account) }

  describe 'POST /sign_in' do
    context 'with SAML user attempting password login' do
      let(:saml_settings) { create(:account_saml_settings, account: account) }
      let(:saml_user) { create(:user, email: 'saml@example.com', provider: 'saml', account: account) }

      before do
        saml_settings
        saml_user
      end

      it 'prevents login and returns SAML authentication error' do
        params = { email: saml_user.email, password: 'Password1!' }

        post new_user_session_url, params: params, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be(false)
        expect(json_response['errors']).to include(I18n.t('messages.login_saml_user'))
      end

      it 'allows login with valid SSO token' do
        valid_token = saml_user.generate_sso_auth_token
        params = { email: saml_user.email, sso_auth_token: valid_token, password: 'Password1!' }

        expect do
          post new_user_session_url, params: params, as: :json
        end.to change(Starchat::AuditLog, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(response.body).to include(saml_user.email)
      end
    end

    context 'with regular user credentials' do
      it 'creates a sign_in audit event wwith valid credentials' do
        params = { email: user.email, password: 'Password1!' }

        expect do
          post new_user_session_url,
               params: params,
               as: :json
        end.to change(Starchat::AuditLog, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(response.body).to include(user.email)

        # Check if the sign_in event is created
        user.reload
        expect(user.audits.last.action).to eq('sign_in')
        expect(user.audits.last.associated_id).to eq(account.id)
        expect(user.audits.last.associated_type).to eq('Account')
      end

      it 'will not create a sign_in audit event with invalid credentials' do
        params = { email: user.email, password: 'invalid' }
        expect do
          post new_user_session_url,
               params: params,
               as: :json
        end.not_to change(Starchat::AuditLog, :count)
      end
    end

    context 'with blank email' do
      it 'skips SAML check and processes normally' do
        params = { email: '', password: 'Password1!' }
        post new_user_session_url, params: params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /sign_out' do
    context 'when it is an authenticated user' do
      it 'signs out the user and creates an audit event' do
        expect do
          delete '/auth/sign_out', headers: user.create_new_auth_token
        end.to change(Starchat::AuditLog, :count).by(1)
        expect(response).to have_http_status(:success)

        user.reload

        expect(user.audits.last.action).to eq('sign_out')
        expect(user.audits.last.associated_id).to eq(account.id)
        expect(user.audits.last.associated_type).to eq('Account')
      end

      it 'records logout_reason as manual by default' do
        delete '/auth/sign_out', headers: user.create_new_auth_token

        user.reload
        audit = user.audits.last
        expect(audit.action).to eq('sign_out')
        expect(audit.audited_changes['logout_reason']).to eq('manual')
      end

      it 'records logout_reason as browser_closed when sent via param' do
        delete '/auth/sign_out?logout_reason=browser_closed', headers: user.create_new_auth_token

        user.reload
        audit = user.audits.last
        expect(audit.action).to eq('sign_out')
        expect(audit.audited_changes['logout_reason']).to eq('browser_closed')
      end

      it 'records the remote_address in the audit event' do
        delete '/auth/sign_out', headers: user.create_new_auth_token

        user.reload
        expect(user.audits.last.audited_changes['ip_address']).to be_present
      end
    end

    context 'when assigned conversations exist' do
      let!(:inbox) { create(:inbox, account: account) }

      before do
        allow_any_instance_of(AutoAssignment::InboxRoundRobinService).to receive(:queue_snapshot).and_return(%w[1 2])
      end

      it 'creates audit logs for open, pending, and snoozed conversations' do
        stub_const('Starchat::DeviseOverrides::SessionsController::LOGOUT_CONVERSATION_LIMIT', 3)

        create(:conversation, inbox: inbox, account: account, assignee: user, status: 'open')
        create(:conversation, inbox: inbox, account: account, assignee: user, status: 'pending')
        create(:conversation, inbox: inbox, account: account, assignee: user, status: 'snoozed')

        expect do
          delete '/auth/sign_out', headers: user.create_new_auth_token
        end.to change { Starchat::AuditLog.where(action: 'assignee_sign_out').count }.by(3)

        statuses = Starchat::AuditLog.where(action: 'assignee_sign_out').map { |log| log.audited_changes['conversation_status'] }
        expect(statuses).to include('open', 'pending', 'snoozed')
      end

      it 'limits the number of conversation audit logs per user' do
        stub_const('Starchat::DeviseOverrides::SessionsController::LOGOUT_CONVERSATION_LIMIT', 2)

        create(:conversation, inbox: inbox, account: account, assignee: user, status: 'open')
        create(:conversation, inbox: inbox, account: account, assignee: user, status: 'pending')
        create(:conversation, inbox: inbox, account: account, assignee: user, status: 'snoozed')

        expect do
          delete '/auth/sign_out', headers: user.create_new_auth_token
        end.to change { Starchat::AuditLog.where(action: 'assignee_sign_out').count }.by(2)
      end
    end
  end
end
