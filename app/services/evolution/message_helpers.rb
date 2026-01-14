# frozen_string_literal: true

module Evolution
  module MessageHelpers
    module_function

    def truthy?(v)
      v == true || v.to_s == 'true' || v.to_s == '1'
    end

    def caption_of(message)
      payload = message[:message] || message['message']
      return nil unless payload.is_a?(Hash)

      cap = payload[:caption].presence || payload['caption'].presence
      return cap if cap.present?

      node = media_node_of(message)
      return nil unless node.is_a?(Hash)

      node[:caption].presence || node['caption'].presence
    end

    def e164_from_jid(jid)
      return if jid.blank?
      num = jid.to_s.split('@').first.to_s.split(':').first.gsub(/\D+/, '')
      return if num.blank?
      num.start_with?('+') ? num : "+#{num}"
    end

    def remote_jid_from(message)
      jid = message.dig(:key, :remoteJid) || message[:remoteJid] || message['remoteJid']
      return if jid.blank?
      jid = jid.to_s.sub(/:\d+@/, '@')
      jid
    end

    def push_name_from(message)
      message[:pushName].presence || message['pushName'].presence
    end

    def from_me?(message)
      val = message[:from_me] || message['from_me'] ||
            message[:fromMe]  || message['fromMe']  ||
            message.dig(:key, :fromMe) ||
            message.dig('key', 'fromMe') ||
            message.dig('key', 'from_me')

      truthy?(val)
    end
    def media_kind_of(message)
      payload = message[:message] || message['message']
      return :text if payload.is_a?(Hash) && (payload[:conversation].present? || payload['conversation'].present?)
      return :unknown unless payload.is_a?(Hash)

      return :image    if payload[:imageMessage]    || payload['imageMessage']
      return :video    if payload[:videoMessage]    || payload['videoMessage']
      return :audio    if payload[:audioMessage]    || payload['audioMessage']
      return :document if payload[:documentMessage] || payload['documentMessage']
      :unknown
    end

    def media_node_of(message)
      payload = message[:message] || message['message']
      return nil unless payload.is_a?(Hash)

      payload[:imageMessage]    || payload['imageMessage']    ||
      payload[:videoMessage]    || payload['videoMessage']    ||
      payload[:audioMessage]    || payload['audioMessage']    ||
      payload[:documentMessage] || payload['documentMessage']
    end

    def base64_and_ext_from_message(message)
      kind     = media_kind_of(message)
      p        = payload_of(message)
      node     = media_node_of(message)
      mimetype = (node && (node[:mimetype] || node['mimetype'])).to_s

      b64 = if node&.[]( :base64 ).present? then node[:base64]
            elsif node&.[]( 'base64' ).present? then node['base64']
            elsif p&.[]( :base64 ).present? then p[:base64]
            elsif p&.[]( 'base64' ).present? then p['base64']
            end

      return [nil, nil, nil] if b64.blank?
      [b64, ext_from_mimetype_or_kind(mimetype, kind), mimetype.presence]
    end

    def source_id_of(message)
      message.dig(:key, :id) ||
      message.dig('key', 'id') ||
      message[:id] ||
      message['id'] ||
      SecureRandom.hex(8)
    end

    def ext_from_mimetype_or_kind(mimetype, kind)
      m = mimetype.to_s.downcase
      case kind
      when :image    then 'jpg'
      when :video    then 'mp4'
      when :audio    then 'ogg'
      when :document then 'bin'
      else
        if m.start_with?('image/') then 'jpg'
        elsif m.start_with?('video/') then 'mp4'
        elsif m.start_with?('audio/') then 'ogg'
        else 'bin'
        end
      end
    end
  end
end  
