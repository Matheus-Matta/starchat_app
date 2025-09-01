# spec/services/evolution/client_spec.rb
# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Evolution::Client do
  let(:base_url) { 'https://api2.star.dev.br' }
  let(:api_key)  { 'c8Ishl6dVDZTORfquwzLIKIMB' }
  let(:headers)  { { 'Content-Type' => 'application/json', 'apikey' => api_key } }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:client)   { described_class.new(base_url: base_url, api_key: api_key) }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  describe '#create_instance' do
    let(:payload) do
      {
        instanceName: 'starchats_support',
        groupsIgnore: true,
        readStatus: true,
        alwaysOnline: true,
        rejectCall: true
      }
    end

    it 'POST /instance/create com sucesso' do
      stub_request(:post, "#{base_url}/instance/create")
        .with(headers: headers, body: payload.to_json)
        .to_return(
          status: 200,
          body: { instance: 'starchats_support', success: true }.to_json,
          headers: json_headers
        )

      resp = client.create_instance(payload)
      expect(resp).to include('success' => true, 'instance' => 'starchats_support')
    end
  end

  describe '#connect_qr' do
    it 'GET /instance/connect/:instance retorna estado e qrcode' do
      stub_request(:get, "#{base_url}/instance/connect/starchats_support")
        .with(headers: headers)
        .to_return(
          status: 200,
          body: {
            instance: 'starchats_support',
            state: 'PAIRING',
            qrcode: 'data:image/png;base64,iVBORw0KGgoAAA...'
          }.to_json,
          headers: json_headers
        )

      resp = client.connect_qr('starchats_support')
      expect(resp['state']).to eq('PAIRING')
      expect(resp['qrcode']).to be_a(String)
    end
  end

  describe '#set_webhook' do
    it 'POST /webhook/instance configura o endpoint de webhook' do
      body = { instanceName: 'starchats_support', url: 'https://27pz5ssk-3001.brs.devtunnels.ms/webhooks/evolution/123' }

      stub_request(:post, "#{base_url}/webhook/instance")
        .with(headers: headers, body: body.to_json)
        .to_return(
          status: 200,
          body: { success: true }.to_json,
          headers: json_headers
        )

      resp = client.set_webhook('starchats_support', 'https://27pz5ssk-3001.brs.devtunnels.ms/webhooks/evolution/123')
      expect(resp['success']).to eq(true)
    end
  end

  describe '#send_text' do
    it 'POST /message/sendText/:instance envia texto' do
      body = { number: '5521991996687', text: 'Olá, mundo!' }

      stub_request(:post, "#{base_url}/message/sendText/starchats_support")
        .with(headers: headers, body: body.to_json)
        .to_return(
          status: 200,
          body: { sent: true, id: 'msg_1' }.to_json,
          headers: json_headers
        )

      resp = client.send_text('starchats_support', number: '5521991996687', text: 'Olá, mundo!')
      expect(resp['sent']).to be(true)
      expect(resp['id']).to eq('msg_1')
    end
  end

  describe '#send_media' do
    it 'POST /message/sendMedia/:instance envia mídia com caption' do
      body = {
        number: '5521991996687',
        mediaMessage: {
          mediaType: 'image',
          media: 'https://cdn.example.com/file.png',
          caption: 'veja isso',
          mimetype: 'image/png'
        }
      }

      stub_request(:post, "#{base_url}/message/sendMedia/starchats_support")
        .with(headers: headers, body: body.to_json)
        .to_return(
          status: 200,
          body: { sent: true, id: 'msg_img_1' }.to_json,
          headers: json_headers
        )

      resp = client.send_media(
        'starchats_support',
        number: '5521991996687',
        mediaType: 'image',
        media: 'https://cdn.example.com/file.png',
        caption: 'veja isso',
        mimetype: 'image/png'
      )
      expect(resp['sent']).to be(true)
      expect(resp['id']).to eq('msg_img_1')
    end
  end
end
