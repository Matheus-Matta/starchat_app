# app/services/evolution/update_message_service.rb
# frozen_string_literal: true

class Evolution::UpdateMessageService
  include ::Evolution::WaUtils  

  def initialize(channel:, message:, new_text:)
    @channel  = channel
    @message  = message
    @new_text = new_text.to_s
    @client   = Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key:  channel.api_key.presence || ENV['EVOLUTION_API_KEY']
    )
  end

  def perform
    return if @new_text.blank?
    return unless (instance = @channel.instance_name).present?
    return if (msg_id = @message.source_id).blank?

    number    = destination_number
    remote_jid = build_remote_jid(number)

    key = { remoteJid: remote_jid, fromMe: true, id: msg_id }
    @client.update_message(instance, number: number, text: @new_text, key: key)
  rescue => e
    Rails.logger.error("[Evolution] update_message error: #{e.class} #{e.message}")
  end

  private

  def destination_number
    @message.conversation&.contact&.phone_number.to_s.gsub(/\D/, '')
  end

  def build_remote_jid(number)
    "#{number}@s.whatsapp.net"
  end
end
