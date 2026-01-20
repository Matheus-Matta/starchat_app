# frozen_string_literal: true

module Evolution
  module MessageReaction
    module_function

    def apply!(inbox_id:, payload:, author_name: nil)
      rx = payload.dig('message', 'reactionMessage') || payload['reactionMessage']
      return false unless rx.is_a?(Hash)

      emoji = rx['text'].to_s.strip
      return false if emoji.empty?

      target_source_id = rx.dig('key', 'id').to_s
      return false if target_source_id.blank?

      parent = ::Message.find_by(inbox_id: inbox_id, source_id: target_source_id)
      unless parent
        Rails.logger.info "[MessageReaction] parent NÃO encontrado (inbox_id=#{inbox_id}, source_id=#{target_source_id})"
        return false
      end

      conv = parent.conversation
      unless conv
        Rails.logger.info "[MessageReaction] conversation do parent ausente (parent_id=#{parent.id})"
        return false
      end

      from_me   = reaction_from_me?(payload)
      source_id = safe_source_id_for(payload)

      if ::Message.exists?(inbox_id: parent.inbox_id, source_id: source_id)
        Rails.logger.info "[MessageReaction] já existe mensagem reaction com source_id=#{source_id}, ignorando duplicata"
        return true
      end

      attrs = {
        content: emoji,        # só o emoji; renderiza como reply no Chatwoot
        content_type: 'text',
        private: false,
        account_id: parent.account_id,
        inbox_id: parent.inbox_id,
        message_type: (from_me ? :outgoing : :incoming),
        source_id: source_id,
        in_reply_to_external_id: nil
      }

      msg = if from_me
              conv.messages.build(attrs)
            else
              # IMPORTANTE: incoming precisa de sender = contato
              conv.messages.build(attrs.merge(sender: conv.contact))
            end

      msg.in_reply_to = parent

      Rails.logger.info "[MessageReaction] tentando salvar reply reaction: emoji=#{emoji.inspect} " \
                        "parent_id=#{parent.id} conv_id=#{conv.id} from_me=#{from_me} source_id=#{source_id}"

      if msg.save
        Rails.logger.info "[MessageReaction] reaction criada id=#{msg.id} " \
                          "in_reply_to=#{msg.in_reply_to_id} message_type=#{msg.message_type}"
        return true
      else
        Rails.logger.warn "[MessageReaction] reply NÃO salvo: #{msg.errors.full_messages.join(', ')}"
        return false
      end
    rescue StandardError => e
      Rails.logger.warn "[MessageReaction] falhou: #{e.class} #{e.message}\n#{e.backtrace&.first}"
      false
    end

    # ==== Helpers =============================================================

    def reaction_from_me?(payload)
      !!(
        payload.dig('message', 'reactionMessage', 'key', 'fromMe') ||
        payload.dig('reactionMessage', 'key', 'fromMe') ||
        payload.dig('key', 'fromMe')
      )
    end

    def safe_source_id_for(payload)
      raw =
        payload['messageId'].presence ||
        payload.dig('message', 'reactionMessage', 'key', 'id').presence ||
        payload.dig('reactionMessage', 'key', 'id').presence ||
        payload.dig('key', 'id').presence

      raw.presence || "rx-#{SecureRandom.hex(8)}"
    end
  end
end
