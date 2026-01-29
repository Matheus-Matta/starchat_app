# app/controllers/webhooks/evolution_controller.rb
# frozen_string_literal: true

require 'open-uri'

class Webhooks::EvolutionController < ActionController::API

  include Evolution::CommonHelpers

  def process_payload
    return head :ok unless (@inbox = Inbox.find_by(id: params[:inbox_id]))

    payload = parse_payload
    event   = normalize_event(payload[:event])
    data    = payload[:data]

    handle_event(event, data)

    # Re-wrap data if necessary for the job
    if %w[messages_upsert messages_update contacts_update chats_update call].include?(event)
      data = [data] if data.is_a?(Hash)

      # Deduplicate messages
      if event == 'messages_upsert'
        data = data.reject { |msg| message_already_processed?(msg) }
        return head :ok if data.empty?
      end
    end

    Webhooks::EvolutionEventsJob.perform_later(inbox_id: @inbox.id, event: event, data: data || [])

    head :ok
  rescue JSON::ParserError
    head :ok
  rescue StandardError => e
    Rails.logger.error("[Evolution] webhook error: #{e.message}")
    head :ok
  end

  private

  def parse_payload
    raw  = request.request_parameters.presence || JSON.parse(request.raw_post)
    evo  = raw['evolution'].is_a?(Hash) ? raw['evolution'] : {}
    data = (raw['data'] || evo['data'])

    {
      event: raw['event'] || evo['event'],
      data: process_data(data)
    }
  end

  def process_data(data)
    if data.is_a?(Array)
      data.map { |x| x.is_a?(Hash) ? x.with_indifferent_access : x }
    elsif data.is_a?(Hash)
      data.with_indifferent_access
    else
      []
    end
  end

  def handle_event(event, data)
    case event
    when 'qrcode_updated'    then handle_qrcode_updated(data)
    when 'connection_update' then handle_connection_update(data)
    end
  end

  def handle_qrcode_updated(data)
    q = (data.is_a?(Hash) ? (data[:qrcode] || {}) : {}).with_indifferent_access
    broadcast_evolution_event('evolution.qrcode_updated', {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      qrcode_base64: q[:base64],
      pairing_code: q[:pairingCode]
    }.compact)
  end

  def handle_connection_update(data)
    state = data.is_a?(Hash) ? data[:state].to_s : nil
    return unless (ch = @inbox.channel).is_a?(Channel::Evolution) && state.present?

    ch.update_state!(state)
    update_channel_phone_number(ch, data)

    # Extract QR if present in connection update (sometimes Evolution sends QR with connection update)
    qr = extract_qr(data)

    broadcast_evolution_event('evolution.connection_update', {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      state: state,
      phone_number: ch&.phone_number,
      qrcode_base64: qr[:base64],
      pairing_code: qr[:pairing_code]
    }.compact)

    # Notify if state is 'refused' (truly disconnected/excluded)
    return unless %w[refused].include?(state)

    create_connection_change_notification(@inbox, state)
  end

  def update_channel_phone_number(channel, data)
    inst_data = data[:instance]
    owner = data[:owner] || (inst_data.is_a?(Hash) ? inst_data[:owner] : nil)
    return if owner.blank?

    channel.phone_number = owner.split('@').first
    channel.save
  end

  def broadcast_evolution_event(event, data)
    ActionCable.server.broadcast("account_#{@inbox.account_id}", { event: event, data: data })
  end

  def normalize_event(e)
    e.to_s.tr('.', '_').downcase
  end

  def message_already_processed?(msg_data)
    unique_id = msg_data.dig('key', 'id')
    return false if unique_id.blank?

    # Returns true (processed) if Redis key already exists (set returns nil)
    # Returns false (new) if Redis key was set successfully
    !Redis::Alfred.set("evolution:dedup:#{@inbox.id}:#{unique_id}", 1, nx: true, ex: 3.minutes)
  end
end
