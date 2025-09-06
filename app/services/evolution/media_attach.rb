# frozen_string_literal: true
require 'securerandom'

module Evolution
  module MediaAttach
    # requer:
    # - include ::FileTypeHelper (opcional)
    # - include ::DownloadForBase64
    # - include ::DownloadForWhatsappEnc
    #
    # expõe:
    # - attach_from_payload!(message, payload) -> true/false

    def attach_from_payload!(message, payload)
      type, media = Evolution::MediaSelector.pick_first_media(payload)
      return false unless type && media

      # dados principais
      raw_url    = media['url'] || media['directPath']
      url        = Evolution::MediaSelector.normalize_wa_media_url(raw_url)
      media_key  = media['mediaKey']
      mimetype   = media['mimetype'].to_s
      filename   = suggested_filename_from_payload_like_wa(type, mimetype)

      # 1) Tenta fluxo .enc (precisa de url + media_key)
      if url.present? && media_key.present?
        blob = download_for_whatsapp_enc(
          url:          url,
          media_key:    media_key,
          media_type:   type,          # :audio/:video/:image/:document
          filename:     filename,
          content_type: mimetype,
          headers:      {},            # ajuste se houver Auth
          identify:     false
        )
        return attach_blob!(message, blob)
      end

      # 2) Fallback: base64 no payload (jpegThumbnail, base64, etc)
      if (b64 = extract_any_base64(payload)).present?
        blob = download_for_base64(
          b64,
          filename:     filename,
          content_type: mimetype.presence,
          identify:     false
        )
        return attach_blob!(message, blob)
      end

      false
    rescue => e
      Rails.logger.warn "[MediaAttach] erro: #{e.class} #{e.message}"
      false
    end

    private

    def extract_any_base64(p)
      p.dig('message', 'base64') ||
        p['base64'] ||
        p.dig('message', 'imageMessage', 'base64') ||
        p.dig('message', 'videoMessage', 'base64') ||
        p.dig('message', 'audioMessage', 'base64') ||
        p.dig('message', 'documentMessage', 'base64') ||
        p['jpegThumbnail'] || p.dig('imageMessage', 'jpegThumbnail')
    end

    def suggested_filename_from_payload_like_wa(type, mimetype)
      ext = case
            when mimetype.start_with?('image/jpeg') then '.jpg'
            when mimetype.start_with?('image/png')  then '.png'
            when mimetype.start_with?('image/gif')  then '.gif'
            when mimetype.start_with?('image/webp') then '.webp'
            when mimetype.start_with?('video/mp4')  then '.mp4'
            when mimetype.start_with?('audio/ogg')  then '.ogg'
            when mimetype.start_with?('audio/mpeg') then '.mp3'
            else ''
            end
      "file-#{SecureRandom.hex(4)}#{ext}"
    end

    def attach_blob!(message, blob)
      att = message.attachments.build(account_id: message.account_id)
      att.file.attach(blob)
      att.file_type = safe_file_type_for(blob.content_type)

      if (url = presigned_url_for(blob))
        Rails.logger.info "[ATTACH] blob=#{blob.id} key=#{blob.key} filename=#{blob.filename} ct=#{blob.content_type} url=#{url}"
      else
        Rails.logger.info "[ATTACH] blob=#{blob.id} key=#{blob.key} filename=#{blob.filename} ct=#{blob.content_type}"
      end
      true
    end

    # — utilidades já usadas no seu serviço —
    def presigned_url_for(blob, expires_in: 15.minutes, disposition: 'inline')
      if blob.respond_to?(:url)
        blob.url(expires_in:, disposition:, filename: blob.filename)
      elsif blob.respond_to?(:service_url)
        blob.service_url(expires_in:, disposition:, filename: blob.filename)
      end
    end

    def file_type_from_content_type(ct)
      return 'image' if ct.to_s.start_with?('image/')
      return 'video' if ct.to_s.start_with?('video/')
      return 'audio' if ct.to_s.start_with?('audio/')
      'file'
    end

    def safe_file_type_for(content_type)
      ct = content_type.to_s
      return file_type(ct) if respond_to?(:file_type)
      if defined?(::FileTypeHelper) && ::FileTypeHelper.respond_to?(:file_type)
        return ::FileTypeHelper.file_type(ct)
      end
      file_type_from_content_type(ct)
    end
  end
end
