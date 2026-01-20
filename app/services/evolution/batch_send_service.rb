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

      # 1. Enviar texto primeiro (se houver) e validações iniciais
      # Usamos skip_attachments: true para que ele só envie o texto e não bloqueie
      Evolution::SendMessageService.new(message: @message, skip_attachments: true).perform

      # 2. Agendar envio de anexos em background (ActiveJob)
      # Isso garante que não bloqueamos a thread principal e podemos usar retry/backoff do Sidekiq
      @message.attachments.each_with_index do |attachment, index|
        # Calcula delay:
        # Ex: 1 texto já foi.
        # Anexo 1: delay 1s
        # Anexo 2: delay 3s
        # ...
        delay = (index + 1) * rand(2..5).seconds

        Evolution::SendAttachmentJob.set(wait: delay).perform_later(@message.id, attachment.id)
      end
    end
  end
end
