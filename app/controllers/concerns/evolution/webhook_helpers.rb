# app/controllers/concerns/evolution/webhook_helpers.rb
module Evolution::WebhookHelpers
  extend ActiveSupport::Concern

  def handle_messages(messages)
    Webhooks::EvolutionEventsJob.perform_later(
      inbox_id: @inbox.id,
      event: 'messages_upsert',
      data: { messages: messages }
    )
  end

  def handle_status(updates)
    Webhooks::EvolutionEventsJob.perform_later(
      inbox_id: @inbox.id,
      event: 'messages_update',
      data: updates
    )
  end

  def handle_presence_update(payload_hash)
    Webhooks::EvolutionPresenceJob.perform_later(
      inbox_id: @inbox.id,
      payload: payload_hash
    )
  end

  def handle_contacts_update(list)
    Webhooks::EvolutionContactsJob.perform_later(
      inbox_id: @inbox.id,
      list: Array(list)
    )
  end

  def handle_chats_update(list)
    Webhooks::EvolutionChatsJob.perform_later(
      inbox_id: @inbox.id,
      list: Array(list)
    )
  end
  
  included do
    private

    def normalize_msisdn(str)
      str.to_s.gsub(/\D/, '').sub(/@.*/, '')
    end

    def extract_text(m)
      m['text'] || m.dig('message', 'conversation') || m.dig('message', 'extendedTextMessage', 'text')
    end

    def extract_media_url(m)
      m['mediaUrl'] ||
        m.dig('message', 'imageMessage', 'url') ||
        m.dig('message', 'videoMessage', 'url') ||
        m.dig('message', 'audioMessage', 'url') ||
        m.dig('message', 'documentMessage', 'url')
    end

    def filename_for(m)
      m['filename'] || "wa_#{SecureRandom.hex(4)}"
    end

    def content_type_for(m)
      m['mimetype'] || 'application/octet-stream'
    end

    def attach_remote_media(message, url, filename, content_type)
      io = URI.parse(url).open
      message.attachments.build(
        account_id: message.account_id,
        file_type: content_type,
        file: { io: io, filename: filename, content_type: content_type }
      )
    rescue => e
      Rails.logger.warn("[Evolution] attach media failed: #{e.class} #{e.message}")
    end
  end
end
