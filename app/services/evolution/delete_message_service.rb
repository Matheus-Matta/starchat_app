# frozen_string_literal: true

class Evolution::DeleteMessageService
  pattr_initialize [:channel!, :message!]

  def perform
    return unless message.source_id.present?

    client = Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key: channel.api_key.presence || ENV.fetch('AUTHENTICATION_API_KEY', nil)
    )

    number = message.conversation.contact_inbox.source_id

    client.delete_message(channel.instance_name, id: message.source_id, number: number)

    Rails.logger.info("[Evolution::DeleteMessageService] Deleted msg=#{message.id} source_id=#{message.source_id}")
  rescue Evolution::Client::Error => e
    Rails.logger.warn("[Evolution::DeleteMessageService] API error msg=#{message.id}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[Evolution::DeleteMessageService] #{e.class} msg=#{message.id}: #{e.message}")
  end
end
