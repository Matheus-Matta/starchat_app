# app/jobs/evolution/send_attachment_job.rb
class Evolution::SendAttachmentJob < ApplicationJob
  queue_as :default

  retry_on Evolution::Client::Error, wait: :exponentially_longer, attempts: 5

  def perform(message_id, attachment_id)
    ActiveStorage::Current.url_options = { host: ENV['FRONTEND_URL'] || 'http://localhost:3000' }

    message = Message.find(message_id)
    attachment = message.attachments.find(attachment_id)

    # Reutiliza a lógica de envio (agora focada em 1 anexo)
    # Precisamos adaptar o SendMessageService ou extrair o método de envio de anexo.
    # Para simplicidade, vamos instanciar o serviço e chamar um método específico (que vamos criar).

    service = Evolution::SendMessageService.new(message: message)
    service.send_single_attachment(attachment)

    # Marca como enviado/entregue se sucesso
    service.update_message_status!(message: message, status: 'delivered', external_error: nil)
  end
end
