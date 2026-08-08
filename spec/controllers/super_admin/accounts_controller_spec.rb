require 'rails_helper'

RSpec.describe 'Super Admin accounts API', type: :request do
  include ActiveJob::TestHelper

  let!(:super_admin) { create(:super_admin) }
  let!(:account) { create(:account) }

  describe 'GET /super_admin/accounts' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get '/super_admin/accounts'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows the list of accounts' do
        sign_in(super_admin, scope: :super_admin)
        get '/super_admin/accounts'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New account')
        expect(response.body).to include(account.name)
      end
    end
  end

  describe 'GET /super_admin/accounts/{account_id}' do
    context 'when it is an authenticated user' do
      it 'shows effective Cosmos model routing', if: ChatwootApp.enterprise? do
        account.update!(cosmos_models: { 'editor' => 'gpt-4.1' })
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/accounts/#{account.id}"
        document = Nokogiri::HTML(response.body)
        summaries = document.css('details summary').map { |summary| summary.text.squish }

        expect(response).to have_http_status(:success)
        expect(document.at_css('#cosmos_models').text.squish).to eq('Cosmos models')
        expect(summaries).to include('View model routing')
        expect(summaries).not_to include('All features')
        expect(summaries).not_to include('Cosmos models')
        expect(response.body).to include('Editor', 'OpenAI', 'openai', 'gpt-4.1', 'Account override', 'Label suggestion', 'Default')
      end
    end
  end

  describe 'GET /super_admin/accounts/{account_id}/edit' do
    context 'when it is an authenticated user' do
      it 'renders a Cosmos model selector for every AI feature', if: ChatwootApp.enterprise? do
        account.update!(cosmos_models: { 'editor' => 'gpt-4.1' })
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/accounts/#{account.id}/edit"

        expect(response).to have_http_status(:success)
        Llm::Models.feature_keys.each do |feature_key|
          expect(response.body).to include("account[cosmos_models][#{feature_key}]")
        end

        document = Nokogiri::HTML(response.body)
        editor_select = document.at_css('select[name="account[cosmos_models][editor]"]')
        default_model_id = Llm::Models.default_model_for('editor')
        default_model = Llm::Models.model_config(default_model_id)['display_name']

        expect(editor_select.at_css('option[value=""]').text.squish).to eq("Use default: #{default_model} (#{default_model_id})")
      end

      it 'shows the Cosmos V2 assistant default in the model selector', if: ChatwootApp.enterprise? do
        account.enable_features!('cosmos_integration_v2')
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/accounts/#{account.id}/edit"

        document = Nokogiri::HTML(response.body)
        assistant_select = document.at_css('select[name="account[cosmos_models][assistant]"]')
        default_model_id = Llm::FeatureRouter::COSMOS_V2_ASSISTANT_MODEL
        default_model = Llm::Models.model_config(default_model_id)['display_name']

        expect(response).to have_http_status(:success)
        expect(assistant_select.at_css('option[value=""]').text.squish).to eq("Use default: #{default_model} (#{default_model_id})")
      end
    end
  end

  describe 'PATCH /super_admin/accounts/{account_id}' do
    context 'when it is an authenticated user' do
      it 'updates Cosmos model overrides without changing unrelated settings' do
        account.update!(
          cosmos_models: { 'editor' => 'gpt-4.1' },
          keep_pending_on_bot_failure: true
        )
        sign_in(super_admin, scope: :super_admin)

        patch "/super_admin/accounts/#{account.id}",
              params: {
                account: {
                  name: account.name,
                  locale: account.locale,
                  status: account.status,
                  cosmos_models: {
                    editor: '',
                    assistant: 'gpt-5.2'
                  }
                }
              }

        expect(response).to have_http_status(:redirect)
        expect(account.reload.cosmos_models).to eq('assistant' => 'gpt-5.2')
        expect(account.keep_pending_on_bot_failure).to be true
      end

      it 'rejects invalid Cosmos model overrides' do
        sign_in(super_admin, scope: :super_admin)
        existing_cosmos_models = account.cosmos_models

        patch "/super_admin/accounts/#{account.id}",
              params: {
                account: {
                  name: account.name,
                  locale: account.locale,
                  status: account.status,
                  cosmos_models: {
                    label_suggestion: 'gpt-5.1'
                  }
                }
              }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('not a valid model for label_suggestion')
        expect(account.reload.cosmos_models).to eq(existing_cosmos_models)
      end
    end
  end

  describe 'POST /super_admin/accounts/{account_id}/reset_cache' do
    before do
      create(:label, account: account)
      create(:inbox, account: account)
      create(:team, account: account)
    end

    after do
      Conversations::UnreadCounts::Store.clear_account!(account.id)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/super_admin/accounts/#{account.id}/reset_cache"
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows the list of accounts' do
        expect(account.cache_keys.keys).to contain_exactly(:inbox, :label, :team)
        sign_in(super_admin, scope: :super_admin)

        now_timestamp = Time.now.utc.to_i
        post "/super_admin/accounts/#{account.id}/reset_cache"
        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to eq('Cache keys cleared')

        range = now_timestamp..(now_timestamp + 10)
        expect(account.reload.cache_keys.values.all? { |v| range.cover?(v.to_i) }).to be(true)
      end

      it 'clears conversation unread count cache' do
        inbox = account.inboxes.first
        store = Conversations::UnreadCounts::Store
        inbox_key = store.inbox_key(account.id, inbox.id)
        store.mark_base_ready!(account.id)
        store.add_base_membership(account_id: account.id, inbox_id: inbox.id, label_ids: [], conversation_id: 1)

        sign_in(super_admin, scope: :super_admin)
        post "/super_admin/accounts/#{account.id}/reset_cache"

        expect(response).to have_http_status(:redirect)
        expect(store.base_ready?(account.id)).to be(false)
        expect(store.counts_for_keys([inbox_key])).to eq(inbox_key => 0)
      end
    end
  end

  describe 'DELETE /super_admin/accounts/{account_id}' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/super_admin/accounts/#{account.id}"
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'Deletes the account' do
        total_accounts = Account.count
        sign_in(super_admin, scope: :super_admin)

        perform_enqueued_jobs(only: DeleteObjectJob) do
          delete "/super_admin/accounts/#{account.id}"
        end

        expect(Account.count).to eq(total_accounts - 1)
      end
    end
  end

  describe 'PATCH /super_admin/accounts/{account_id}' do
    it 'allows a super admin to enable the YCloud account feature' do
      sign_in(super_admin, scope: :super_admin)

      patch "/super_admin/accounts/#{account.id}", params: {
        account: { name: account.name, locale: account.locale, status: account.status },
        enabled_features: { feature_channel_ycloud: 'true' }
      }

      expect(response).to have_http_status(:redirect)
      expect(account.reload.feature_enabled?('channel_ycloud')).to be(true)
    end
  end
end
