# app/services/evolution/delete_message_service.rb
# frozen_string_literal: true

class Evolution::DeleteMessageService
  def initialize(channel:, message:)
    @channel = channel
    @message = message
    @client  = Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key:  channel.api_key.presence || ENV['EVOLUTION_API_KEY']
    )
  end

  def perform
    return unless (instance = @channel.instance_name).present?
    return if (msg_id = @message.source_id).blank?

    number    = destination_number
    remote_jid = build_remote_jid(number)

    @client.delete_message_for_everyone(
      instance,
      id: msg_id,
      remoteJid: remote_jid,
      fromMe: true
    )
  rescue => e
    Rails.logger.error("[Evolution] delete_message error: #{e.class} #{e.message}")
  end

  private

  def destination_number
    @message.conversation&.contact&.phone_number.to_s.gsub(/\D/, '')
  end

  def build_remote_jid(number)
    "#{number}@s.whatsapp.net"
  end
end
