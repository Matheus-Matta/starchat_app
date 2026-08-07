require 'rails_helper'

RSpec.describe 'Webhooks::YcloudController', type: :request do
  let(:secret) { 'ycloud-webhook-secret' }
  let(:account) do
    create(:account).tap { |record| record.enable_features!(:channel_ycloud) }
  end
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'ycloud',
      provider_config: {
        'api_key' => 'ycloud-key',
        'waba_id' => 'waba-123',
        'phone_number_id' => 'phone-123',
        'webhook_secret' => secret
      },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:payload) do
    {
      id: 'evt-123',
      type: 'whatsapp.inbound_message.received',
      whatsappInboundMessage: {
        id: 'yc-inbound-1',
        wabaId: 'waba-123',
        from: '+5511888888888',
        to: channel.phone_number,
        type: 'text',
        text: { body: 'Hello' }
      }
    }
  end

  def signature(body, timestamp = Time.current.to_i)
    digest = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")
    "t=#{timestamp},s=#{digest}"
  end

  it 'enqueues a valid signed webhook for the matching tenant' do
    body = payload.to_json

    expect do
      post '/webhooks/ycloud',
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json', 'YCloud-Signature' => signature(body) }
    end.to have_enqueued_job(Webhooks::YcloudEventsJob).with(channel.id, payload.deep_stringify_keys)

    expect(response).to have_http_status(:ok)
  end

  it 'rejects an invalid signature' do
    post '/webhooks/ycloud',
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'YCloud-Signature' => 't=123,s=invalid' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'acknowledges an event that does not belong to an installed channel' do
    unknown_payload = payload.deep_dup
    unknown_payload[:whatsappInboundMessage][:wabaId] = 'unknown-waba'

    post '/webhooks/ycloud',
         params: unknown_payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:ok)
  end

  it 'does not enqueue events when YCloud is disabled for the account' do
    channel
    account.disable_features!(:channel_ycloud)
    body = payload.to_json

    expect do
      post '/webhooks/ycloud',
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json', 'YCloud-Signature' => signature(body) }
    end.not_to have_enqueued_job(Webhooks::YcloudEventsJob)

    expect(response).to have_http_status(:ok)
  end
end
