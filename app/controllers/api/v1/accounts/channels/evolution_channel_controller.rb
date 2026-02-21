require 'timeout'
class Api::V1::Accounts::Channels::EvolutionChannelController < Api::V1::Accounts::BaseController
  before_action :load_channel, only: %i[show connect restart disconnect settings update_settings]

  # GET /api/v1/accounts/:account_id/channels/evolution_channel/:id
  def show
    render json: { channel: @channel.as_json(methods: :phone_number) }
  end

  def create
    name = extract_name!(params[:evolution_channel])

    # Cria canal e inbox primeiro para ter IDs e gerar o instance_name correto via modelo
    channel = Channel::Evolution.create!(account: Current.account)
    inbox   = Inbox.create!(name: name, account: Current.account, channel: channel)

    # Reload para garantir que pegamos o instance_name gerado pelo callback
    channel.reload
    inst = channel.instance_name

    # Se por acaso falhar callback (improvável), gera manual
    if inst.blank?
      channel.send(:assign_instance_name!)
      inst = channel.instance_name
    end

    evo     = evo_client(api_key: ENV.fetch('AUTHENTICATION_API_KEY', nil))
    webhook = "#{base_host}/webhooks/evolution/#{inbox.id}"

    payload = build_create_payload(
      instance_name: inst,
      name: name,
      webhook_url: webhook
    )

    evo_resp = to_hash(evo.create_instance(payload))
    api_key  = evo_resp['hash'].presence || ENV.fetch('AUTHENTICATION_API_KEY', nil)
    inst_id  = evo_resp['instanceId'] || evo_resp.dig('instance', 'instanceId') || evo_resp.dig('instance', 'id')

    channel.update!(
      api_key: api_key,
      webhook_url: webhook,
      provider_config: { instance_id: inst_id }.compact
    )

    if (qr = extract_qr(evo_resp)).present?
      broadcast(Current.account.id, 'evolution.qrcode_updated', {
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        qrcode_base64: qr[:base64],
        pairing_code: qr[:pairing_code]
      }.compact)
    end

    render json: { inbox: inbox, channel: channel }, status: :created
  rescue StandardError => e
    Rails.logger.error("[Evolution] create error: #{e.class} #{e.message}")
    begin
      inbox&.destroy
    rescue StandardError
      nil
    end
    begin
      channel&.destroy
    rescue StandardError
      nil
    end
    render_error(e)
  end

  # POST /api/v1/accounts/:account_id/channels/evolution_channel/:id/connect
  def connect
    evo = evo_client(@channel)
    @channel.update_state!('connecting')

    begin
      raw = evo.connect_qr(@channel.instance_name) # GET /instance/connect/{instance}
      h   = to_hash(raw)

      return broadcast_open!(@channel, phone_number: extract_phone_number(h)) if read_instance_state(h) == 'open'

      qr = extract_qr(h)
      return handle_qr_and_render(@channel, qr)

    rescue StandardError => e
      if not_found_error?(e)
        Rails.logger.warn('[Evolution] connect_qr 404, creating instance then retry...')
        ensure_instance_exists!(@channel)
        evo = evo_client(@channel) # reabre cliente (api_key pode ter mudado)

        raw2 = evo.connect_qr(@channel.instance_name)
        h2   = to_hash(raw2)

        return broadcast_open!(@channel, phone_number: extract_phone_number(h2)) if read_instance_state(h2) == 'open'

        qr2 = extract_qr(h2)
        return handle_qr_and_render(@channel, qr2)
      end

      handle_error_state(@channel, e)
    end
  end

  # POST /api/v1/accounts/:account_id/channels/evolution_channel/:id/restart
  def restart
    evo = evo_client(@channel)

    begin
      raw = nil
      Timeout.timeout(2) do
        raw = evo.restart_instance(@channel.instance_name) # PUT /instance/restart/{instance}
      end

      h   = to_hash(raw)
      new_state = read_instance_state(h).presence || 'connecting'
      @channel.update_state!(new_state)

      if %w[open connected].include?(new_state)
        broadcast_open!(@channel, phone_number: extract_phone_number(h))
      else
        connect
      end
    rescue Timeout::Error
      Rails.logger.warn('[Evolution] restart_instance timed out (2s), falling back to connect')
      connect
    rescue StandardError => e
      Rails.logger.error("[Evolution] restart_instance error: #{e.class} #{e.message}, fallback to connect")
      connect
    end
  end

  def disconnect
    evo = evo_client(@channel)

    begin
      evo.logout_instance(@channel.instance_name)
    rescue Evolution::Client::Error => e
      # Ignore if instance not found (404), unprocessable (422) or Bad Request (400)
      # Evolution often returns 400/422 if instance is already logged out
      unless [400, 404, 422].include?(e.status)
        Rails.logger.error("[Evolution] logout_instance error: #{e.class} #{e.message}")
        render_error(e) and return
      end
      Rails.logger.warn("[Evolution] logout_instance ignored error: #{e.status} #{e.message}")
    rescue StandardError => e
      Rails.logger.error("[Evolution] logout_instance unexpected error: #{e.class} #{e.message}")
      render_error(e) and return
    end

    inbox = inbox_for(@channel)
    create_connection_change_notification(inbox, 'disconnected') if inbox.present?

    @channel.update_state!('disconnected')

    broadcast(@channel.account_id, 'evolution.connection_update', {
                account_id: @channel.account_id,
                inbox_id: inbox_for(@channel)&.id,
                state: @channel.state
              })

    head :no_content
  rescue StandardError => e
    render_error(e)
  end

  # GET /api/v1/accounts/:account_id/channels/evolution_channel/:id/settings
  def settings
    evo = evo_client(@channel)

    # Fetch snake_case settings from Evolution
    # ex: { "reject_call" => false, ... }
    remote = evo.find_settings(@channel.instance_name)

    # Convert to camelCase for frontend consistency
    normalized = remote.transform_keys { |k| k.to_s.camelize(:lower) }

    # Merge local-only fields (not known by Evolution API) from DB
    render json: normalized.merge(local_only_settings)
  rescue StandardError => e
    Rails.logger.error("[Evolution] settings failed: #{e.class} #{e.message}")

    # Fallback: tentar usar configurações salvas localmente
    stored = (@channel.provider_config || {})['settings']
    if stored.present?
      render json: stored.transform_keys { |k| k.to_s.camelize(:lower) }
    elsif not_found_error?(e)
      render json: local_only_settings
    else
      render_error(e)
    end
  end

  # PATCH /api/v1/accounts/:account_id/channels/evolution_channel/:id/settings
  def update_settings
    # Frontend sends camelCase settings
    # payload: { rejectCall: true, msgCall: "...", ... }

    # Whitelist params
    # Check if inside 'settings' (frontend usually wraps it)
    source = params[:settings].present? ? params.require(:settings) : params

    permitted = source.permit(
      :rejectCall, :msgCall, :groupsIgnore, :alwaysOnline,
      :readMessages, :readStatus, :syncFullHistory, :wavoipToken,
      :sendAgentName, :syncContactName
    ).to_h

    # Force restricted values
    permitted[:groupsIgnore] = true
    permitted[:syncFullHistory] = false

    # 1. Update DB (persist "desired" state)
    conf = @channel.provider_config || {}
    conf['settings'] = permitted
    @channel.update!(provider_config: conf)

    # 2. Push to Evolution (only fields the Evolution API understands)
    evo = evo_client(@channel)
    evolution_payload = permitted.except('syncContactName', 'sendAgentName')
    updated = evo.set_settings(@channel.instance_name, evolution_payload)

    # Evolution returns object, we normalize again just in case (though POST returns 201 with body)
    # Always merge local-only fields back so frontend keeps them.

    if updated.is_a?(Hash)
      render json: updated.transform_keys { |k| k.to_s.camelize(:lower) }.merge(local_only_settings)
    else
      render json: permitted # Fallback if empty response (already has all fields)
    end
  rescue StandardError => e
    render_error(e)
  end

  include Evolution::CommonHelpers

  private

  def handle_qr_and_render(channel, qr)
    if qr.present?
      channel.update_state!('qrcode')
      broadcast(channel.account_id, 'evolution.qrcode_updated', {
        account_id: channel.account_id,
        inbox_id: inbox_for(channel)&.id,
        qrcode_base64: qr[:base64],
        pairing_code: qr[:pairing_code]
      }.compact)
    end

    render json: { state: channel.state, qrcode_base64: qr[:base64], pairing_code: qr[:pairing_code] }
  end

  def handle_error_state(channel, error)
    Rails.logger.error("[Evolution] action error: #{error.class} #{error.message}")
    channel.update_state!('error')
    render_error(error, state: channel.state)
  end

  # ===== Payload v2 =====

  def build_create_payload(instance_name:, name:, webhook_url:)
    {
      instanceName: instance_name,
      qrcode: true,
      integration: 'WHATSAPP-BAILEYS',
      rejectCall: false,
      groupsIgnore: true,
      alwaysOnline: false,
      readMessages: false,
      readStatus: false,
      webhook: {
        enabled: true,
        url: webhook_url,
        byEvents: false,
        base64: false, # Forçar false para economizar banda
        headers: { 'Content-Type' => 'application/json' },
        events: get_events
      },
      rabbitmq: {
        enabled: false,
        events: get_events
      }
    }
  end

  def get_events
    %w[
      APPLICATION_STARTUP
      CONNECTION_UPDATE
      QRCODE_UPDATED
      MESSAGES_UPSERT
      MESSAGES_UPDATE
      MESSAGES_DELETE
      CALL
    ]
  end

  # ===== Utils de resposta =====

  def extract_phone_number(h)
    owner = h.dig('instance', 'owner') || h['owner']
    return if owner.blank?

    owner.split('@').first
  end

  # ===== Infra =====

  def load_channel
    @channel = Channel::Evolution.find_by!(id: params[:id], account_id: Current.account.id)
  end

  def evo_client(channel = nil, api_key: nil)
    Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key: channel&.api_key.presence || api_key.presence || ENV.fetch('AUTHENTICATION_API_KEY'),
      open_timeout: Integer(ENV.fetch('EVOLUTION_HTTP_OPEN_TIMEOUT', 180)),
      read_timeout: Integer(ENV.fetch('EVOLUTION_HTTP_READ_TIMEOUT', 180))
    )
  end

  def inbox_for(channel)
    @inbox_for_channel ||= Inbox.find_by(account_id: channel.account_id, channel_id: channel.id)
  end

  def broadcast(account_id, event, data)
    ActionCable.server.broadcast("account_#{account_id}", { event: event, data: data })
  rescue StandardError => e
    Rails.logger.error("[Evolution] WS broadcast error: #{e.class} #{e.message}")
  end

  # Fields stored only in the DB (not synced to / returned by Evolution API)
  LOCAL_ONLY_SETTINGS = %w[syncContactName sendAgentName].freeze

  def local_only_settings
    stored = (@channel.provider_config || {})['settings'] || {}
    LOCAL_ONLY_SETTINGS.each_with_object({}) do |key, h|
      h[key] = stored.key?(key) ? stored[key] : default_local_setting(key)
    end
  end

  def default_local_setting(key)
    case key
    when 'syncContactName' then false
    when 'sendAgentName'   then false
    else nil
    end
  end

  def broadcast_open!(channel, phone_number: nil)
    channel.update_state!('open')

    if phone_number.present?
      channel.phone_number = phone_number
      channel.save
    end

    broadcast(channel.account_id, 'evolution.connection_update', {
                account_id: channel.account_id,
                inbox_id: inbox_for(channel)&.id,
                state: 'open',
                phone_number: channel.phone_number
              })
    render json: { state: 'open', phone_number: channel.phone_number }
  end

  def base_host
    raw = ENV.fetch('FRONTEND_URL', nil)
    uri = URI.parse(raw)
    host = "#{uri.scheme}://#{uri.host}"
    host += ":#{uri.port}" if uri.port && [80, 443].exclude?(uri.port)
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

  # ===== v2 helpers =====

  def not_found_error?(error)
    msg  = error.message.to_s
    code = (error.respond_to?(:status) && error.status) || nil
    msg.match?(/not\s*found/i) || code == 404
  end

  def ensure_instance_exists!(channel)
    evo     = evo_client(channel)
    webhook = channel.webhook_url.presence || computed_webhook_url_for(channel)

    payload = build_create_payload(
      instance_name: channel.instance_name,
      name: inbox_for(channel)&.name || "Inbox #{channel.id}",
      webhook_url: webhook
    )

    resp    = to_hash(evo.create_instance(payload))
    api_key = resp['hash'].presence || channel.api_key.presence || ENV.fetch('AUTHENTICATION_API_KEY', nil)
    inst_id = resp['instanceId'] || resp.dig('instance', 'instanceId') || resp.dig('instance', 'id')

    channel.update!(
      api_key: api_key,
      webhook_url: webhook,
      provider_config: (channel.provider_config || {}).merge('instance_id' => inst_id).compact
    )

    channel.update_state!('connecting')
    channel
  end

  def safe_delete_instance!(channel)
    evo = evo_client(channel)
    begin
      evo.logout_instance(channel.instance_name) # DELETE /instance/logout/{instance}
    rescue StandardError => e
      Rails.logger.warn("[Evolution] logout before delete failed: #{e.class} #{e.message}")
    end

    begin
      evo.delete_instance(channel.instance_name) # DELETE /instance/delete/{instance}
    rescue StandardError => e
      Rails.logger.warn("[Evolution] delete_instance failed: #{e.class} #{e.message}")
    end
  end

  def computed_webhook_url_for(channel)
    base  = base_host
    inbox = inbox_for(channel)
    return if base.blank? || inbox.blank?

    "#{base}#{Channel::Evolution::WEBHOOK_PATH_PREFIX}/#{inbox.id}"
  end
end
