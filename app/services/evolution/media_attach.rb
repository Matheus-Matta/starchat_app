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

      raw_url    = media['url'] || media['directPath']
      url        = Evolution::MediaSelector.normalize_wa_media_url(raw_url)
      media_key  = media['mediaKey']
      if media_key.is_a?(Hash)
        # Converte Hash de bytes {"0"=>123, "1"=>45} em String binária
        bytes = media_key.sort_by { |k, _v| k.to_i }.map { |_k, v| v }.pack('C*')
        # DownloadForWhatsappEnc espera Base64 Strict
        media_key = Base64.strict_encode64(bytes)
      elsif media_key.is_a?(Array)
        # Se vier como Array de bytes [123, 45, ...]
        bytes = media_key.pack('C*')
        media_key = Base64.strict_encode64(bytes)
      end
      mimetype   = media['mimetype'].to_s
      filename   = suggested_filename_from_payload_like_wa(type, mimetype)

      # 1) Preferência: base64 (no payload OU dentro de media)
      b64 = extract_any_base64(payload)
      b64 ||= media['base64'] if media.is_a?(Hash) && media['base64'].present?

      if b64.present?
        Rails.logger.info "[MediaAttach] Found Base64. Processing..."
        blob = download_for_base64(
          b64,
          filename:     filename,
          content_type: mimetype.presence,
          identify:     false
        )
        return attach_blob!(message, blob)
      end

      # 2) Fallback: fluxo .enc (url + media_key)
      if url.present? && media_key.present?
        Rails.logger.info "[MediaAttach] Trying .enc download from #{url}..."
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

      # 3) Fallback: URL simples (sem base64, sem media_key)
      # Caso o webhook mande uma URL pública ou acessível
      if url.present?
        Rails.logger.info "[MediaAttach] Trying simple download from #{url}..."
        begin
          blob = download_simple_url(url, filename, mimetype)
          return attach_blob!(message, blob)
        rescue => e
          Rails.logger.warn "[MediaAttach] Simple URL download failed: #{e.message}"
        end
      end

      false
    rescue => e
      Rails.logger.warn "[MediaAttach] erro: #{e.class} #{e.message}"
      false
    end

    private

    def extract_any_base64(p)
      candidates = [
        p['base64'],
        p.dig('message', 'base64'),

        p.dig('message', 'imageMessage', 'base64'),
        p.dig('message', 'videoMessage', 'base64'),
        p.dig('message', 'audioMessage', 'base64'),
        p.dig('message', 'documentMessage', 'base64'),

        p.dig('message', 'imageMessage', 'data'),
        p.dig('message', 'videoMessage', 'data'),
        p.dig('message', 'audioMessage', 'data'),
        p.dig('message', 'documentMessage', 'data'),

        p.dig('message', 'imageMessage', 'file'),
        p.dig('message', 'videoMessage', 'file'),
        p.dig('message', 'audioMessage', 'file'),
        p.dig('message', 'documentMessage', 'file')
      ]

      # Retorna o primeiro candidato que seja String e não vazio.
      # Ignora Hashes/Arrays (como jpegThumbnail ou keys cruas)
      candidates.find { |c| c.is_a?(String) && c.present? }
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

      begin
        if (url = presigned_url_for(blob))
          Rails.logger.info "[ATTACH] blob=#{blob.id} key=#{blob.key} filename=#{blob.filename} ct=#{blob.content_type} url=#{url}"
        else
          Rails.logger.info "[ATTACH] blob=#{blob.id} key=#{blob.key} filename=#{blob.filename} ct=#{blob.content_type}"
        end
      rescue => e
        Rails.logger.warn "[ATTACH] blob=#{blob.id} saved, but failed to generate URL for log: #{e.message}"
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

    def download_simple_url(url, filename, content_type)
      require 'down'
      tempfile = Down.download(url, max_size: 50 * 1024 * 1024) # 50MB limit
      
      ActiveStorage::Blob.create_and_upload!(
        io:           tempfile,
        filename:     filename,
        content_type: content_type
      )
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
