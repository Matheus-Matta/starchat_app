# app/controllers/webhooks/evolution_controller.rb
# frozen_string_literal: true

require 'open-uri'

class Webhooks::EvolutionController < ActionController::API
  include Evolution::WebhookHelpers

  def process_payload
    @inbox = Inbox.find_by(id: params[:inbox_id])
    unless @inbox
      Rails.logger.info("[Evolution] webhook: inbox #{params[:inbox_id]} não disponível; ignorando")
      return head :ok
    end

    raw      = request.request_parameters.presence || JSON.parse(request.raw_post)
    evo      = raw['evolution'].is_a?(Hash) ? raw['evolution'] : {}
    event    = normalize_event(raw['event'] || evo['event'])
    raw_data = (raw['data'] || evo['data'])

    data =
      if raw_data.is_a?(Array)
        raw_data.map { |x| x.is_a?(Hash) ? x.with_indifferent_access : x }
      elsif raw_data.is_a?(Hash)
        raw_data.with_indifferent_access
      else
        []
      end

    case event
    when 'qrcode_updated'
      q = (data.is_a?(Hash) ? (data[:qrcode] || {}) : {}).with_indifferent_access
      ActionCable.server.broadcast(
        "account_#{@inbox.account_id}",
        { event: 'evolution.qrcode_updated',
          data: { account_id: @inbox.account_id, inbox_id: @inbox.id,
                  qrcode_base64: q[:base64], pairing_code: q[:pairingCode] }.compact }
      )
    when 'connection_update'
      state = data.is_a?(Hash) ? data[:state].to_s : nil
      if (ch = @inbox.channel).is_a?(Channel::Evolution) && state.present?
        ch.update_state!(state)

        # Saves phone number if available (e.g. owner JID)
        owner = data[:owner] || data.dig(:instance, :owner)
        if owner.present?
          ch.phone_number = owner.split('@').first
          ch.save
        end
      end
      ActionCable.server.broadcast(
        "account_#{@inbox.account_id}",
        { event: 'evolution.connection_update',
          data: { account_id: @inbox.account_id, inbox_id: @inbox.id, state: state, phone_number: ch&.phone_number } }
      )
    end

    data = [data] if %w[messages_upsert messages_update contacts_update chats_update].include?(event) && data.is_a?(Hash)

    Webhooks::EvolutionEventsJob.perform_later(inbox_id: @inbox.id, event: event, data: data || [])

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.warn("[Evolution] payload parse falhou: #{e.class} #{e.message}")
    head :ok
  rescue StandardError => e
    Rails.logger.error("[Evolution] erro de webhook: #{e.class} #{e.message} bt=#{e.backtrace&.first(3)&.join(' | ')}")
    head :ok
  end

  private

  def normalize_event(e)
    e.to_s.tr('.', '_').downcase
  end
end
