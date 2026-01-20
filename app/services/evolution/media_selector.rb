# frozen_string_literal: true

module Evolution
  module MediaSelector
    module_function

    def pick_first_media(payload)
      h = payload.is_a?(Hash) ? payload : {}
      audio    = h['audioMessage']    || h.dig('message', 'audioMessage')
      video    = h['videoMessage']    || h.dig('message', 'videoMessage')
      image    = h['imageMessage']    || h.dig('message', 'imageMessage')
      document = h['documentMessage'] || h.dig('message', 'documentMessage')

      return [:audio,    audio]    if audio.is_a?(Hash)
      return [:video,    video]    if video.is_a?(Hash)
      return [:image,    image]    if image.is_a?(Hash)
      return [:document, document] if document.is_a?(Hash)

      [nil, nil]
    end

    def normalize_wa_media_url(url_or_path)
      return if url_or_path.blank?
      return url_or_path if %r{\Ahttps?://}i.match?(url_or_path)

      "https://mmg.whatsapp.net#{url_or_path}"
    end
  end
end
