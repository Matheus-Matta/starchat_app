# frozen_string_literal: true

class Api::V1::Accounts::Channels::EvolutionChannelController < Api::V1::Accounts::BaseController
  before_action :load_channel, only: %i[show connect restart disconnect]

  # POST /api/v1/accounts/:account_id/channels/evolution_channel
  def create
    name = extract_name!(params[:evolution_channel])

    channel = Channel::Evolution.create!(account: Current.account)
    inbox   = Inbox.create!(name:, account: Current.account, channel:)
    inst    = "acc#{Current.account.id}_inbox#{inbox.id}"

    evo     = evo_client(api_key: ENV['EVOLUTION_API_KEY'])
    webhook = "#{base_host}/webhooks/evolution/#{inbox.id}"

    payload = build_create_payload(
      instance_name: inst,
      name:,
      webhook_url: webhook,
      account_id: Current.account.id,
      base_host:
    )

    evo_resp = to_hash(evo.create_instance(payload))
    api_key  = evo_resp['hash'].presence || ENV['EVOLUTION_API_KEY']
    inst_id  = evo_resp['instanceId'] || evo_resp.dig('instance', 'instanceId') || evo_resp.dig('instance', 'id')

    channel.update!(
      instance_name:   inst,
      api_key:         api_key,
      webhook_url:     webhook,
      provider_config: { instance_id: inst_id }.compact
    )

    if (qr = extract_qr(evo_resp)).present?
      broadcast(Current.account.id, 'evolution.qrcode_updated', {
        account_id:    inbox.account_id,
        inbox_id:      inbox.id,
        qrcode_base64: qr[:base64],
        pairing_code:  qr[:pairing_code]
      }.compact)
    end

    render json: { inbox:, channel: }, status: :created
  rescue StandardError => e
    Rails.logger.error("[Evolution] create error: #{e.class} #{e.message}")
    inbox&.destroy rescue nil
    channel&.destroy rescue nil
    render_error(e)
  end

  # GET /api/v1/accounts/:account_id/channels/evolution_channel/:id
  def show
    render json: { channel: @channel }
  end

  # POST /api/v1/accounts/:account_id/channels/evolution_channel/:id/connect
  def connect
    evo = evo_client(@channel)
    @channel.update_state!('connecting')

    raw = evo.connect_qr(@channel.instance_name)
    h   = to_hash(raw)

    if read_instance_state(h) == 'open'
      return broadcast_open!(@channel)
    end

    qr = extract_qr(h)
    handle_qr_and_render(@channel, qr)
  rescue StandardError => e
    handle_error_state(@channel, e)
  end

  # POST /api/v1/accounts/:account_id/channels/evolution_channel/:id/restart
  def restart
    evo = evo_client(@channel)
    begin

      raw_restart = evo.restart_instance(@channel.instance_name) # PUT /instance/restart/:instance
      h_restart   = to_hash(raw_restart)

      if read_instance_state(h_restart) == 'open'
        return broadcast_open!(@channel)
      end

      @channel.update_state!('connecting')

      raw_connect = evo.connect_qr(@channel.instance_name)
      h_connect   = to_hash(raw_connect)

      if read_instance_state(h_connect) == 'open'
        return broadcast_open!(@channel)
      end

      qr = extract_qr(h_connect)
      handle_qr_and_render(@channel, qr)
    rescue StandardError => e
      Rails.logger.warn("[Evolution] restart_instance failed: #{e.class} #{e.message}, fallback to delete")
    end
  rescue StandardError => e
    handle_error_state(@channel, e)
  end

  # POST /api/v1/accounts/:account_id/channels/evolution_channel/:id/disconnect
  def disconnect
    evo = evo_client(@channel)

    begin
      evo.logout_instance(@channel.instance_name) # DELETE /instance/logout/:instance
    rescue StandardError => e
      Rails.logger.warn("[Evolution] logout_instance failed: #{e.class} #{e.message}, trying delete")
      evo.delete_instance(@channel.instance_name) rescue nil
    end

    @channel.update_state!('disconnected')

    broadcast(@channel.account_id, 'evolution.connection_update', {
      account_id: @channel.account_id,
      inbox_id:   inbox_for(@channel)&.id,
      state:      @channel.state
    })

    head :no_content
  rescue StandardError => e
    render_error(e)
  end

  private

  # ===== Helpers de fluxo =====

  def handle_qr_and_render(channel, qr)
    if qr.present?
      channel.update_state!('qrcode')
      broadcast(channel.account_id, 'evolution.qrcode_updated', {
        account_id:    channel.account_id,
        inbox_id:      inbox_for(channel)&.id,
        qrcode_base64: qr[:base64],
        pairing_code:  qr[:pairing_code]
      }.compact)
    end

    render json: { state: channel.state, qrcode_base64: qr[:base64], pairing_code: qr[:pairing_code] }
  end

  def handle_error_state(channel, error)
    Rails.logger.error("[Evolution] action error: #{error.class} #{error.message}")
    channel.update_state!('error')
    render_error(error, state: channel.state)
  end

  def build_create_payload(instance_name:, name:, webhook_url:, account_id:, base_host:)
    {
      instanceName: instance_name,
      qrcode:       true,
      integration:  'WHATSAPP-BAILEYS',
      rejectCall:   false,
      groupsIgnore: true,
      alwaysOnline: false,
      readMessages: false,
      readStatus:   false,
      webhook: {
        url:      webhook_url,
        byEvents: false,
        base64:   true,
        headers:  { 'Content-Type' => 'application/json' },
        events:   [
          "APPLICATION_STARTUP",
          "MESSAGES_UPSERT",
          "MESSAGES_UPDATE",
          "MESSAGES_DELETE",
          "CONNECTION_UPDATE",
          "QRCODE_UPDATED",
          "MESSAGES_SET",
          "CONTACTS_UPDATE",
          "CONTACTS_SET",
          "CONTACTS_UPSERT"
        ]
      }
    }
  end

  def extract_qr(resp)
    h = to_hash(resp)
    q = h['qrcode'] || h.dig('data', 'qrcode') || h.dig('instance', 'qrcode') || {}

    base64 = q['base64'] || h['base64'] || h.dig('data', 'base64')
    pair   = q['pairingCode'] || h['pairingCode'] || h.dig('data', 'pairingCode')

    { base64:, pairing_code: pair }.compact
  end

  def to_hash(resp)
    return resp if resp.is_a?(Hash)
    return JSON.parse(resp) if resp.is_a?(String)
    {}
  rescue JSON::ParserError
    {}
  end

  # ===== Infra =====

  def load_channel
    @channel = Channel::Evolution.find_by!(id: params[:id], account_id: Current.account.id)
  end

  def read_instance_state(h)
    (h.dig('instance', 'state') || h['state']).to_s.downcase
  end
  
  def evo_client(channel = nil, api_key: nil)
    Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key:  api_key.presence || channel&.api_key.presence || ENV['EVOLUTION_API_KEY']
    )
  end

  def inbox_for(channel)
    @inbox_for_channel ||= Inbox.find_by(account_id: channel.account_id, channel_id: channel.id)
  end

  def broadcast(account_id, event, data)
    ActionCable.server.broadcast("account_#{account_id}", { event:, data: })
  rescue StandardError => e
    Rails.logger.error("[Evolution] WS broadcast error: #{e.class} #{e.message}")
  end

  def broadcast_open!(channel)
    channel.update_state!('open')
    broadcast(channel.account_id, 'evolution.connection_update', {
      account_id: channel.account_id,
      inbox_id:   inbox_for(channel)&.id,
      state:      'open'
    })
    render json: { state: 'open' }
  end

  def base_host
    raw = ENV['FRONTEND_URL'].presence || Rails.application.routes.default_url_options[:host].to_s
    raw = "https://#{raw}" unless raw.include?('://')
    uri = URI.parse(raw)
    host = "#{uri.scheme}://#{uri.host}"
    host += ":#{uri.port}" if uri.port && ![80, 443].include?(uri.port)
    host
  end

  def extract_name!(ec)
    name =
      if ec.is_a?(ActionController::Parameters) || ec.is_a?(Hash)
        (ec[:name] || ec['name']).to_s
      else
        ec.to_s
      end.strip
    raise ArgumentError, 'name required' if name.blank?
    name
  end

  def render_error(error, extra = {})
    render json: { message: error.message }.merge(extra), status: :unprocessable_entity
  end
end
