
require 'rails_helper'

RSpec.describe Channel::Whatsapp, type: :model do
  describe 'Manual Cloud API channel creation' do
    let(:account) { create(:account) }
    let(:valid_params) do
      {
        provider: 'whatsapp_cloud',
        phone_number: '+5521997307980',
        business_account_id: '871210376399942',
        phone_number_id: '593495060503698',
        api_key: 'EAAN9q8dZBL6IBQqI5vmmmxyDBKaJPpEcHoHyyX7W3OpPsNvl0ACumhoC00IPP5zZBKt3iQQFLGTEmaMtF4Wzy30l213D6i7RW5qhHKS3ZBNmOiCe5mTUiBZBsjDd0N04OqA3O5zE47ZAJmeFGK4EoWTZBD977VydobzzuIhw76i3zZC6ENU7ppJeGX1mZCjydlpZCTKS1O6uzeZCBWWqrUCNpOlgnKisHf37ScKJ2aCzPKgAv6ZB0ZArnCgq1RFG9SNsPOVhFjvBdMHfVfZCNQNwxOyZCPNoRC7UwY7DANZBQZDZD'
      }
    end

    before do
      # 1. Validation stub (Fetch Message Templates) based on validate_provider_config
      stub_request(:get, "https://graph.facebook.com/v14.0/#{valid_params[:business_account_id]}/message_templates?access_token=#{valid_params[:api_key]}")
        .to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      # 2. Template Sync stub (Fetch Message Templates after save)
      # It might call the same URL, so the stub above covers it.
      
      # 3. Webhook Setup Stub (usually skipped for non-embedded, but verifying logic)
      # The logic says `should_auto_setup_webhooks?` returns true if provider is whatsapp_cloud and source IS NOT embedded_signup.
      # Wait, looking at the code in Channel::Whatsapp:
      # provider == 'whatsapp_cloud' && provider_config['source'] != 'embedded_signup'
      # So it WILL try to setup webhooks for manual manual setup too if we are not careful (or if it's desired).
      # The previous spec file says "doesn't setup webhooks for manual setup" but let's check the code:
      # return false if Rails.env.test?  <-- THIS!!
      
      # In test env, it returns false. So we don't need to stub Webhooks unless we mock Rails.env.
    end

    it 'creates the channel successfully with real-like data' do
      channel = Channel::Whatsapp.new(
        account: account,
        phone_number: valid_params[:phone_number],
        provider: 'whatsapp_cloud',
        provider_config: {
          api_key: valid_params[:api_key],
          phone_number_id: valid_params[:phone_number_id],
          business_account_id: valid_params[:business_account_id]
        }
      )

      expect(channel.save).to be_truthy
      expect(channel.phone_number).to eq(valid_params[:phone_number])
      expect(channel.provider_config['api_key']).to eq(valid_params[:api_key])
      expect(channel.provider_config['phone_number_id']).to eq(valid_params[:phone_number_id])
      expect(channel.provider_config['business_account_id']).to eq(valid_params[:business_account_id])
    end
    
    it 'creates an Inbox with the channel successfully' do
      ActiveRecord::Base.transaction do
        channel = Channel::Whatsapp.create!(
          account: account,
          phone_number: valid_params[:phone_number],
          provider: 'whatsapp_cloud',
          provider_config: {
            api_key: valid_params[:api_key],
            phone_number_id: valid_params[:phone_number_id],
            business_account_id: valid_params[:business_account_id]
          }
        )
        
        inbox = account.inboxes.create!(
          name: 'Whatsapp - Vendas',
          channel: channel
        )
        
        expect(inbox).to be_persisted
        expect(inbox.channel).to eq(channel)
        expect(inbox.name).to eq('Whatsapp - Vendas')
      end
    end
  end
end
