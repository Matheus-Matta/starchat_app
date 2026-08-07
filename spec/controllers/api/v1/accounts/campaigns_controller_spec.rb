require 'rails_helper'

RSpec.describe 'Campaigns API', type: :request do
  let(:account) { create(:account) }

  describe 'GET /api/v1/accounts/{account.id}/campaigns' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/campaigns"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }
      let(:inbox) { create(:inbox, account: account) }
      let!(:campaign) { create(:campaign, account: account, inbox: inbox, trigger_rules: { url: 'https://test.com' }) }

      it 'returns unauthorized for agents' do
        get "/api/v1/accounts/#{account.id}/campaigns",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns all campaigns to administrators' do
        get "/api/v1/accounts/#{account.id}/campaigns",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body.first[:id]).to eq(campaign.display_id)
      end

      it 'returns campaigns ordered by most recently created first' do
        older_campaign = campaign
        newer_campaign = create(:campaign, account: account, inbox: inbox, created_at: 1.day.from_now,
                                            trigger_rules: { url: 'https://test.com' })

        get "/api/v1/accounts/#{account.id}/campaigns",
            headers: administrator.create_new_auth_token,
            as: :json

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body.map { |c| c[:id] }).to eq([newer_campaign.display_id, older_campaign.display_id])
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/campaigns/:id' do
    let(:campaign) { create(:campaign, account: account, trigger_rules: { url: 'https://test.com' }) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unauthorized for agents' do
        get "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'shows the campaign for administrators' do
        get "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:id]).to eq(campaign.display_id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/campaigns' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/campaigns",
             params: { inbox_id: inbox.id, title: 'test', message: 'test message' },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unauthorized for agents' do
        post "/api/v1/accounts/#{account.id}/campaigns",
             params: { inbox_id: inbox.id, title: 'test', message: 'test message' },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'creates a new campaign' do
        post "/api/v1/accounts/#{account.id}/campaigns",
             params: { inbox_id: inbox.id, title: 'test', message: 'test message' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:title]).to eq('test')
      end

      it 'creates a new ongoing campaign' do
        post "/api/v1/accounts/#{account.id}/campaigns",
             params: { inbox_id: inbox.id, title: 'test', message: 'test message', trigger_rules: { url: 'https://test.com' } },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:title]).to eq('test')
      end

      it 'throws error when invalid url provided for ongoing campaign' do
        post "/api/v1/accounts/#{account.id}/campaigns",
             params: { inbox_id: inbox.id, title: 'test', message: 'test message', trigger_rules: { url: 'javascript' } },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'creates a new oneoff campaign' do
        twilio_sms = create(:channel_twilio_sms, account: account)
        twilio_inbox = create(:inbox, channel: twilio_sms, account: account)
        label1 = create(:label, account: account)
        label2 = create(:label, account: account)
        scheduled_at = 2.days.from_now

        post "/api/v1/accounts/#{account.id}/campaigns",
             params: {
               inbox_id: twilio_inbox.id, title: 'test', message: 'test message',
               scheduled_at: scheduled_at,
               audience: [{ type: 'Label', id: label1.id }, { type: 'Label', id: label2.id }]
             },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:campaign_type]).to eq('one_off')
        expect(response_data[:scheduled_at].present?).to be true
        expect(response_data[:scheduled_at]).to eq(scheduled_at.to_i)
        expect(response_data[:audience].pluck(:id)).to include(label1.id, label2.id)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/campaigns/:id' do
    let(:inbox) { create(:inbox, account: account) }
    let!(:campaign) { create(:campaign, account: account, trigger_rules: { url: 'https://test.com' }) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
              params: { inbox_id: inbox.id, title: 'test', message: 'test message' },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unauthorized for agents' do
        patch "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
              params: { inbox_id: inbox.id, title: 'test', message: 'test message' },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'updates the campaign' do
        patch "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
              params: { inbox_id: inbox.id, title: 'test', message: 'test message' },
              headers: administrator.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body, symbolize_names: true)[:title]).to eq('test')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/campaigns/:id' do
    let(:inbox) { create(:inbox, account: account) }
    let!(:campaign) { create(:campaign, account: account, trigger_rules: { url: 'https://test.com' }) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'return unauthorized if agent' do
        delete "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'delete campaign if admin' do
        delete "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}",
               headers: administrator.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(Campaign.exists?(campaign.display_id)).to be false
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/campaigns/preview_contacts' do
    let(:administrator) { create(:user, account: account, role: :administrator) }

    it 'returns the count and contacts for a ContactList audience with multiple contact_ids' do
      contacts = create_list(:contact, 3, account: account)

      post "/api/v1/accounts/#{account.id}/campaigns/preview_contacts",
           params: { audience: [{ type: 'ContactList', contact_ids: contacts.map(&:id), label: 'Importação (3 contatos)' }], page: 1 },
           headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['count']).to eq(3)
      expect(body['contacts'].pluck('id')).to match_array(contacts.map(&:id))
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/campaigns/match_contacts' do
    let(:administrator) { create(:user, account: account, role: :administrator) }
    let(:agent) { create(:user, account: account, role: :agent) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/campaigns/match_contacts", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
             params: { phones: ['+5511999998888'] }, headers: agent.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when matching existing contacts by phone' do
      let!(:contact) { create(:contact, account: account, phone_number: '+5511999998888') }

      it 'returns the matched contact' do
        post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
             params: { phones: ['+5511999998888'] }, headers: administrator.create_new_auth_token, as: :json

        body = response.parsed_body
        expect(body['matched']).to eq(1)
        expect(body['contacts'].first['id']).to eq(contact.id)
      end

      it 'normalizes phones without a plus sign before matching' do
        post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
             params: { phones: ['5511999998888'] }, headers: administrator.create_new_auth_token, as: :json

        expect(response.parsed_body['matched']).to eq(1)
      end
    end

    context 'when create_missing is enabled' do
      it 'creates a contact for an unmatched phone using the number as name' do
        expect do
          post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
               params: { phones: ['+5511977776666'], create_missing: true },
               headers: administrator.create_new_auth_token, as: :json
        end.to change { account.contacts.count }.by(1)

        body = response.parsed_body
        expect(body['created']).to eq(1)
        expect(body['unmatched']).to eq(0)
        created = account.contacts.find_by(phone_number: '+5511977776666')
        expect(created.name).to eq('+5511977776666')
        expect(body['contacts'].map { |c| c['id'] }).to include(created.id)
      end

      it 'uses the name from phone_names when provided' do
        post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
             params: {
               phones: ['+5511977776666'],
               create_missing: true,
               phone_names: { '+5511977776666' => 'João' }
             },
             headers: administrator.create_new_auth_token, as: :json

        expect(account.contacts.find_by(phone_number: '+5511977776666').name).to eq('João')
      end

      it 'normalizes a phone without plus and creates it in E.164 format' do
        post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
             params: { phones: ['5511977776666'], create_missing: true },
             headers: administrator.create_new_auth_token, as: :json

        expect(account.contacts.find_by(phone_number: '+5511977776666')).to be_present
      end

      it 'does not create a contact when it already exists' do
        create(:contact, account: account, phone_number: '+5511977776666')

        expect do
          post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
               params: { phones: ['+5511977776666'], create_missing: true },
               headers: administrator.create_new_auth_token, as: :json
        end.not_to(change { account.contacts.count })

        body = response.parsed_body
        expect(body['matched']).to eq(1)
        expect(body['created']).to eq(0)
      end

      it 'does not create contacts when create_missing is absent' do
        expect do
          post "/api/v1/accounts/#{account.id}/campaigns/match_contacts",
               params: { phones: ['+5511977776666'] },
               headers: administrator.create_new_auth_token, as: :json
        end.not_to(change { account.contacts.count })

        expect(response.parsed_body['created']).to eq(0)
      end
    end
  end
end
