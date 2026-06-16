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

    INVALID_WA_URLS = [
      'https://web.whatsapp.net',
      'https://a.whatsapp.net'
    ].freeze
    MIME_TYPE_EXTENSIONS = {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      'video/mp4' => '.mp4',
      'audio/ogg' => '.ogg',
      'audio/mpeg' => '.mp3'
    }.freeze

    def attach_from_payload!(message, payload)
      type, media = Evolution::MediaSelector.pick_first_media(payload)
      return false unless type && media

      raw_url = select_raw_url(media)
      url = Evolution::MediaSelector.normalize_wa_media_url(raw_url)
      media_key = normalize_media_key(media['mediaKey'])

      mimetype = media['mimetype'].to_s
      filename = suggested_filename_from_payload_like_wa(type, mimetype)

      # 1) Preferência: base64 (no payload OU dentro de media)
      if (b64 = extract_b64(payload, media)).present?
        Rails.logger.info '[MediaAttach] Found Base64. Processing...'
        blob = download_for_base64(b64, filename: filename, content_type: mimetype.presence, identify: false)
        return attach_blob!(message, blob)
      end

      # 2) Fallback: fluxo .enc (url + media_key)
      if url.present? && media_key.present?
        Rails.logger.info "[MediaAttach] Trying .enc download from #{url}..."
        blob = download_for_whatsapp_enc(
          url: url,
          media_key: media_key,
          media_type: type,
          filename: filename,
          content_type: mimetype,
          headers: {},
          identify: false
        )
        return attach_blob!(message, blob)
      end

      # 3) Fallback: URL simples
      try_simple_download(message, url, filename, mimetype)
    end

    private

    def select_raw_url(media)
      url = media['url']
      if url.blank? || INVALID_WA_URLS.include?(url)
        media['directPath']
      else
        url
      end
    end

    def normalize_media_key(key)
      return nil if key.blank?
      return key if key.is_a?(String)

      bytes = if key.is_a?(Hash)
                key.sort_by { |k, _| k.to_i }.map { |_, v| v }
              elsif key.is_a?(Array)
                key
              else
                return nil
              end

      Base64.strict_encode64(bytes.pack('C*'))
    end

    def extract_b64(payload, media)
      b64 = extract_any_base64(payload)
      b64 ||= media['base64'] if media.is_a?(Hash) && media['base64'].present?
      b64
    end

    def extract_any_base64(p)
      candidates = [
        p['base64'],
        p.dig('message', 'base64'),
        p.dig('message', 'imageMessage', 'base64'),
        p.dig('message', 'videoMessage', 'base64'),
        p.dig('message', 'audioMessage', 'base64'),
        p.dig('message', 'documentMessage', 'base64'),
        p.dig('message', 'stickerMessage', 'base64'),
        p.dig('message', 'imageMessage', 'data'),
        p.dig('message', 'videoMessage', 'data'),
        p.dig('message', 'audioMessage', 'data'),
        p.dig('message', 'documentMessage', 'data'),
        p.dig('message', 'stickerMessage', 'data'),
        p.dig('message', 'imageMessage', 'file'),
        p.dig('message', 'videoMessage', 'file'),
        p.dig('message', 'audioMessage', 'file'),
        p.dig('message', 'documentMessage', 'file'),
        p.dig('message', 'stickerMessage', 'file'),
        p.dig('message', 'imageMessage', 'jpegThumbnail'),
        p.dig('message', 'videoMessage', 'jpegThumbnail'),
        p.dig('message', 'audioMessage', 'jpegThumbnail'),
        p.dig('message', 'documentMessage', 'jpegThumbnail')
      ]
      candidates.find { |c| c.is_a?(String) && c.present? }
    end

    def suggested_filename_from_payload_like_wa(type, mimetype)
      ext = MIME_TYPE_EXTENSIONS.find { |k, _v| mimetype.start_with?(k) }&.last || ''
      "file-#{SecureRandom.hex(4)}#{ext}"
    end

    # Alias for backward compatibility
    alias suggested_filename_from_type_and_mime suggested_filename_from_payload_like_wa

    def try_simple_download(message, url, filename, mimetype)
      return false if url.blank?

      Rails.logger.info "[MediaAttach] Trying simple download from #{url}..."
      begin
        blob = download_simple_url(url, filename, mimetype)
        attach_blob!(message, blob)
      rescue StandardError => e
        Rails.logger.warn "[MediaAttach] Simple URL download failed: #{e.message}"
        false
      end
    end

    def attach_blob!(message, blob)
      att = message.attachments.build(account_id: message.account_id)
      att.file.attach(blob)
      att.file_type = safe_file_type_for(blob.content_type)

      begin
        if (url = presigned_url_for(blob))
          Rails.logger.info "[ATTACH] blob=#{blob.id} key=#{blob.key} filename=#{blob.filename} ct=#{blob.content_type} url=#{url}"
        else
          Rails.logger.info "[ATTACH] blob=#{blob.id} key=#{blob.key} filename=#{blob.filename} ct=#{blob.content_type}"
        end
      rescue StandardError => e
        Rails.logger.warn "[ATTACH] blob=#{blob.id} saved, but failed to generate URL for log: #{e.message}"
      end
      true
    end

    # — utilidades já usadas no seu serviço —
    def presigned_url_for(blob, expires_in: 15.minutes, disposition: 'inline')
      if blob.respond_to?(:url)
        blob.url(expires_in: expires_in, disposition: disposition, filename: blob.filename)
      elsif blob.respond_to?(:service_url)
        blob.service_url(expires_in: expires_in, disposition: disposition, filename: blob.filename)
      end
    end

    def file_type_from_content_type(ct)
      return 'image' if ct.to_s.start_with?('image/')
      return 'video' if ct.to_s.start_with?('video/')
      return 'audio' if ct.to_s.start_with?('audio/')

      'file'
    end

    def download_simple_url(url, filename, content_type)
      require 'down'
      tempfile = Down.download(url, max_size: 50 * 1024 * 1024) # 50MB limit

      ActiveStorage::Blob.create_and_upload!(
        io: tempfile,
        filename: filename,
        content_type: content_type
      )
    end

    def safe_file_type_for(content_type)
      ct = content_type.to_s
      return file_type(ct) if respond_to?(:file_type)
      return ::FileTypeHelper.file_type(ct) if defined?(::FileTypeHelper) && ::FileTypeHelper.respond_to?(:file_type)

      file_type_from_content_type(ct)
    end
  end
end
