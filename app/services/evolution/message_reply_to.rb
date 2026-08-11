# frozen_string_literal: true

module Evolution
  module MessageReplyTo
    module_function

    # ==== Public ==============================================================
    # Ajusta a mensagem para ser uma reply padrão do Starchats.
    # - Localiza o parent via stanzaId/quotedStanzaId
    # - Seta `message.in_reply_to` (ou `in_reply_to_external_id` se não achar)
    # - NÃO altera o conteúdo da mensagem (nada de "> quoted")
    #
    # Retorna true se aplicou relação de reply, false se não havia referência.
    def apply!(message, payload)
      stanza_id = extract_quoted_stanza_id(payload).to_s
      return false if stanza_id.blank?

      if (parent = ::Message.find_by(inbox_id: message.inbox_id, source_id: stanza_id))
        message.in_reply_to = parent
      else
        message.in_reply_to_external_id = stanza_id
      end

      true
    end

    # ==== Internos ============================================================
    def dig_context_info(p)
      p['contextInfo'] ||
        p.dig('message', 'contextInfo') ||
        p.dig('message', 'extendedTextMessage', 'contextInfo') ||
        p.dig('message', 'imageMessage', 'contextInfo') ||
        p.dig('message', 'videoMessage', 'contextInfo') ||
        p.dig('message', 'documentMessage', 'contextInfo') ||
        p.dig('message', 'audioMessage', 'contextInfo')
    end

    def extract_quoted_stanza_id(p)
      ci = dig_context_info(p)
      return unless ci.is_a?(Hash)

      ci['stanzaId'] || ci['quotedStanzaID'] || ci['quotedStanzaId']
    end
  end
end
