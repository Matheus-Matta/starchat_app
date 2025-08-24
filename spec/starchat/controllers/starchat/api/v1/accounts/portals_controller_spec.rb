describe 'GET /api/v1/accounts/{account.id}/portals/{portal.slug}/ssl_status' do
  let(:portal_with_domain) { create(:portal, slug: 'portal-with-domain', account_id: account.id, custom_domain: 'docs.example.com') }

  context 'when it is an unauthenticated user' do
    it 'returns unauthorized' do
      get "/api/v1/accounts/#{account.id}/portals/#{portal_with_domain.slug}/ssl_status"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when it is an authenticated user' do
    it 'returns error when custom domain is not configured' do
      get "/api/v1/accounts/#{account.id}/portals/#{portal.slug}/ssl_status",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Custom domain is not configured')
    end

    it 'returns success when portal has custom domain' do
      get "/api/v1/accounts/#{account.id}/portals/#{portal_with_domain.slug}/ssl_status",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to be_nil
      expect(response.parsed_body['verification_errors']).to be_nil
    end
  end
end
