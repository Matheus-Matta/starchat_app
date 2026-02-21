# app/services/evolution/batch_send_service.rb
# frozen_string_literal: true

module Evolution
  class BatchSendService
    def initialize(message:)
      @message = message
      @channel = message.conversation.inbox.channel
    end

    def perform
      return if @message.incoming? || @message.private? || @message.activity?

      attachments = @message.attachments.to_a

      if attachments.any?
        # Estratégia: enviar o texto como CAPTION do primeiro anexo (padrão WhatsApp).
        # Demais anexos são enviados sem caption.
        text_caption = build_caption

        attachments.each_with_index do |attachment, index|
          caption_for_this = index.zero? ? text_caption : nil
          delay = (index + 1) * rand(2..5).seconds
          Evolution::SendAttachmentJob.set(wait: delay).perform_later(@message.id, attachment.id, caption_for_this)
        end
      else
        # Sem anexos: envia somente o texto normalmente
        Evolution::SendMessageService.new(message: @message, skip_attachments: true).perform
      end
    end

    private

    def build_caption
      return nil if @message.content.blank?

      inbox         = @message.conversation.inbox
      sender_config = inbox.sender_config || {}
      text          = @message.outgoing_content.to_s.strip

      if sender_config['send_agent_name'] && @message.sender.is_a?(User)
        agent_name = @message.sender.try(:display_name).presence || @message.sender.name
        text = "*#{agent_name}:*\n#{text}" if agent_name.present?
      end

      text.presence
    end
  end
end
