require 'rails_helper'

RSpec.describe Api::V1::Accounts::Channels::EvolutionChannelController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:evolution_client) { instance_double(Evolution::Client) }

  before do
    allow(Evolution::Client).to receive(:new).and_return(evolution_client)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    
    allow(ENV).to receive(:[]).with('EVOLUTION_API_KEY').and_return('test-api-key')
    allow(ENV).to receive(:[]).with('EVOLUTION_BASE_URL').and_return('http://evolution.test')
    
    allow(ENV).to receive(:fetch).with('EVOLUTION_BASE_URL').and_return('http://evolution.test')
    allow(ENV).to receive(:fetch).with('EVOLUTION_API_KEY').and_return('test-api-key')
    allow(ENV).to receive(:fetch).with('EVOLUTION_HTTP_OPEN_TIMEOUT', 180).and_return(180)
    allow(ENV).to receive(:fetch).with('EVOLUTION_HTTP_READ_TIMEOUT', 180).and_return(180)
  end

  context 'when unauthenticated' do
    it 'returns unauthorized' do
      post :create, params: { account_id: account.id }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when authenticated' do
    before do
      auth_headers = admin.create_new_auth_token
      request.headers.merge!(auth_headers)
    end

    describe 'POST #create' do
      let(:create_params) do
        {
          account_id: account.id,
          evolution_channel: { name: 'Test WhatsApp' }
        }
      end

      let(:evolution_response) do
        {
          'instance' => {
            'instanceId' => 'inst_123',
            'status' => 'created'
          },
          'hash' => 'new-api-key'
        }
      end

      context 'when successful' do
        before do
          allow(evolution_client).to receive(:create_instance).and_return(evolution_response)
        end

        it 'creates a channel and inbox' do
          expect {
            post :create, params: create_params
          }.to change(Channel::Evolution, :count).by(1)
           .and change(Inbox, :count).by(1)

          expect(response).to have_http_status(:created)
          
          json_response = JSON.parse(response.body)
          expect(json_response['inbox']['name']).to eq('Test WhatsApp')
          expect(json_response['channel']['provider_config']).to include('instance_id' => 'inst_123')
        end
      end

      context 'when evolution api fails' do
        before do
          allow(evolution_client).to receive(:create_instance).and_raise(StandardError.new('API Error'))
        end

        it 'returns unprocessable_entity' do
          post :create, params: create_params
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['message']).to eq('API Error')
        end
      end
    end

    describe 'GET #show' do
      let!(:channel) { Channel::Evolution.create!(account: account, instance_name: 'test_inst', api_key: 'key') }
      let!(:inbox) { create(:inbox, channel: channel, account: account) }

      it 'returns the channel details' do
        get :show, params: { account_id: account.id, id: channel.id }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['channel']['id']).to eq(channel.id)
      end
    end

    describe 'POST #restart' do
      let!(:channel) { Channel::Evolution.create!(account: account, instance_name: 'test_inst', api_key: 'key') }
      
      it ' restarts the instance' do
        allow(evolution_client).to receive(:restart_instance).with('test_inst').and_return({ 'instance' => { 'state' => 'open' } })
        
        post :restart, params: { account_id: account.id, id: channel.id }
        
        expect(response).to have_http_status(:ok)
        expect(channel.reload.state).to eq('open')
      end

      it 'falls back to connect on timeout' do
        allow(evolution_client).to receive(:restart_instance).and_raise(Timeout::Error)
        allow(controller).to receive(:connect)
        
        post :restart, params: { account_id: account.id, id: channel.id }
        
        expect(controller).to have_received(:connect)
      end
    end

    describe 'DELETE #disconnect' do
      let!(:channel) { Channel::Evolution.create!(account: account, instance_name: 'test_inst', api_key: 'key', state: 'open') }

      it 'logs out and updates state' do
        allow(evolution_client).to receive(:logout_instance).with('test_inst')
        
        delete :disconnect, params: { account_id: account.id, id: channel.id }
        
        expect(response).to have_http_status(:no_content)
        expect(channel.reload.state).to eq('disconnected')
      end

      it 'tries delete if logout fails' do
        allow(evolution_client).to receive(:logout_instance).and_raise(StandardError)
        allow(evolution_client).to receive(:delete_instance).with('test_inst')
        
        delete :disconnect, params: { account_id: account.id, id: channel.id }
        
        expect(channel.reload.state).to eq('disconnected')
      end
    end
  end
end
