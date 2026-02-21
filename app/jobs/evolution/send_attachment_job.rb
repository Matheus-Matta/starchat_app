# app/jobs/evolution/send_attachment_job.rb
class Evolution::SendAttachmentJob < ApplicationJob
  queue_as :default

  retry_on Evolution::Client::Error, wait: :polynomially_longer, attempts: 5

  def perform(message_id, attachment_id, caption = nil)
    ActiveStorage::Current.url_options = { host: ENV['FRONTEND_URL'] || 'http://localhost:3000' }

    message = Message.find(message_id)
    attachment = message.attachments.find(attachment_id)

    service = Evolution::SendMessageService.new(message: message)
    service.send_single_attachment(attachment, caption: caption)

    # Marca como entregue após envio com sucesso
    service.update_message_status!(message: message, status: 'delivered', external_error: nil)
  end
end
