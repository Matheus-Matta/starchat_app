# frozen_string_literal: true
require 'open-uri'
require 'base64'
require 'json'

module Evolution
  class SendMessageService
    def initialize(channel:, message:)
      @channel = channel
      @message = message
      @client  = ::Evolution::Client.new(
        base_url: ENV.fetch('EVOLUTION_BASE_URL'),
        api_key:  channel.api_key.presence || ENV['EVOLUTION_API_KEY']
      )
    end

    def perform
      return if @message.private?
      return unless (instance = @channel.instance_name).present?

      number = destination_number
      return if number.blank?

      # 1) mídias (se houver)
      if @message.attachments.any?
        @message.attachments.each do |att|
          resp = send_attachment(instance, number, att)
          store_provider_id(resp) # <-- grava o source_id se vier messageId
        end
      end

      # 2) texto (se houver)
      if @message.content.present?
        resp = @client.send_text(instance, number: number, text: @message.content)
        store_provider_id(resp)   # <-- idem para envio de texto
      end
    rescue => e
      Rails.logger.error("[Evolution] send_message error: #{e.class} #{e.message}")
    end

    private

    def destination_number
      contact = @message.conversation&.contact
      num = contact&.phone_number.to_s.gsub(/\D/, '')
      num.presence
    end

    # retorna a resposta do client p/ o chamador poder capturar o id
    def send_attachment(instance, number, attachment)
      ct   = content_type_of(attachment)
      kind = mediatype_for(ct)
      b64  = blob_base64(attachment)
      cap  = @message.content.presence

      if kind == 'audio'
        @client.send_whatsapp_audio(instance, number: number, audio: b64)
      else
        @client.send_media(
          instance,
          number: number,
          mediatype: kind,
          mimetype: ct,
          media: b64,
          caption: cap
        )
      end
    end

    def content_type_of(attachment)
      attachment.try(:file_content_type) ||
        attachment.try(:content_type) ||
        attachment.try(:file)&.content_type ||
        'application/octet-stream'
    end

    def mediatype_for(mime)
      return 'image' if mime.start_with?('image/')
      return 'video' if mime.start_with?('video/')
      return 'audio' if mime.start_with?('audio/')
      'document'
    end

    def blob_base64(attachment)
      url = attachment.try(:file_url) || attachment.try(:download_url) || attachment.try(:external_url)
      data =
        if url.present?
          URI.open(url, 'rb', &:read)
        elsif attachment.respond_to?(:file) && attachment.file.respond_to?(:download)
          attachment.file.download
        else
          File.binread(attachment.file.path)
        end
      Base64.strict_encode64(data)
    end

    # ------ NOVO: helpers para gravar o source_id ------

    # grava o source_id na primeira oportunidade (se já tiver, não sobrescreve)
    def store_provider_id(resp)
      return if @message.source_id.present?
      ext_id = extract_message_id(resp)
      @message.update_column(:source_id, ext_id) if ext_id.present?
    end

    # aceita Hash/Array/String e tenta extrair o id nos formatos mais comuns
    def extract_message_id(resp)
      h =
        case resp
        when Hash then resp
        when Array then resp.first || {}
        when String
          JSON.parse(resp) rescue {}
        else
          {}
        end

      h['messageId'] ||
        h.dig('data', 'messageId') ||
        h['id'] ||
        h.dig('message', 'key', 'id') ||
        h.dig('key', 'id')
    end
  end
end
