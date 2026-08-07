class Whatsapp::IncomingMessageYcloudService < Whatsapp::IncomingMessageWhatsappCloudService
  private

  def download_attachment_file(attachment_payload)
    url = attachment_payload[:link].presence || inbox.channel.media_url(attachment_payload[:id])
    attachment_file = Down.download(url, headers: inbox.channel.api_headers)
    filename = attachment_payload[:filename].presence
    attachment_file.define_singleton_method(:original_filename) { filename } if filename.present?
    attachment_file
  end
end
