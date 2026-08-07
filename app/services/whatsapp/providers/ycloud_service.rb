class Whatsapp::Providers::YcloudService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message
    payloads = message_payloads(phone_number, message)
    responses = payloads.map { |payload| post_message(payload) }
    message_ids = responses.filter_map { |response| response_message_id(response) }
    errors = responses.filter_map { |response| response_error(response) }

    persist_send_result(message, message_ids, errors)
    message_ids.first
  end

  def send_template(phone_number, template_info, message)
    payload = base_payload(phone_number, 'template').merge(
      template: {
        name: template_info[:name],
        language: { code: template_info[:lang_code] },
        components: template_info[:parameters]
      }.compact,
      externalId: message&.id&.to_s
    )

    response = post_message(payload)
    message_id = response_message_id(response)
    persist_send_result(message, Array.wrap(message_id), Array.wrap(response_error(response))) if message.present?
    message_id
  end

  def send_plain_text(phone_number, text)
    response = post_message(
      base_payload(phone_number, 'text').merge(text: { body: text })
    )
    response_message_id(response).present?
  end

  def sync_templates
    templates = fetch_templates
    return false if templates.nil?

    whatsapp_channel.update!(message_templates: templates, message_templates_last_updated: Time.current)
    true
  end

  def fetch_templates(page = 1)
    response = HTTParty.get(
      "#{api_base_path}/templates",
      headers: api_headers,
      query: { 'filter.wabaId': waba_id, limit: 100, page: page }
    )
    unless response.success?
      Rails.logger.warn("[YCLOUD] Could not synchronize templates (HTTP #{response.code})")
      return
    end

    parsed_response = response.parsed_response
    templates = if parsed_response.is_a?(Hash)
                  parsed_response['items'] || parsed_response['data']
                elsif parsed_response.is_a?(Array)
                  parsed_response
                end
    if templates.nil?
      Rails.logger.warn('[YCLOUD] Could not synchronize templates because the response format is invalid')
      return
    end

    templates = Array.wrap(templates)
    return templates if templates.length < 100

    next_page = fetch_templates(page + 1)
    return if next_page.nil?

    templates + next_page
  rescue StandardError => e
    Rails.logger.warn("[YCLOUD] Could not synchronize templates: #{e.message}")
    nil
  end

  def validate_provider_config?
    required_config = %w[api_key waba_id webhook_secret]
    return false unless required_config.all? { |key| whatsapp_channel.provider_config[key].present? }

    response = HTTParty.get(
      "#{api_base_path}/phoneNumbers/#{waba_id}/#{CGI.escape(whatsapp_channel.phone_number)}",
      headers: api_headers
    )
    response.success?
  end

  def api_headers
    {
      'X-API-Key' => whatsapp_channel.provider_config['api_key'],
      'Content-Type' => 'application/json'
    }
  end

  def media_url(media_id)
    "#{api_base_path}/media/download/#{media_id}"
  end

  def mark_message_as_read(message_id)
    response = HTTParty.post(
      "#{api_base_path}/inboundMessages/#{message_id}/markAsRead",
      headers: api_headers
    )
    Rails.logger.warn("[YCLOUD] Could not mark inbound message #{message_id} as read") unless response.success?
    response.success?
  end

  private

  def message_payloads(phone_number, message)
    return [interactive_payload(phone_number, message)] if message.content_type == 'input_select'
    return [text_payload(phone_number, message)] if message.attachments.blank?

    payloads = attachment_payloads(phone_number, message)
    needs_text_payload = message.outgoing_content.present? &&
                         payloads.none? { |payload| payload.dig(payload[:type].to_sym, :caption).present? }
    payloads.unshift(text_payload(phone_number, message)) if needs_text_payload
    payloads
  end

  def post_message(payload)
    HTTParty.post(
      "#{api_base_path}/messages",
      headers: api_headers,
      body: payload.to_json
    )
  end

  def base_payload(phone_number, type)
    recipient = if phone_number.to_s.match?(/\A\+?\d{7,15}\z/)
                  { to: "+#{phone_number.to_s.delete_prefix('+')}" }
                else
                  { recipient: phone_number }
                end

    {
      from: whatsapp_channel.phone_number,
      type: type
    }.merge(recipient)
  end

  def text_payload(phone_number, message)
    base_payload(phone_number, 'text').merge(
      text: { body: message_content(message) },
      context: reply_context(message),
      externalId: external_id(message)
    ).compact
  end

  def attachment_payloads(phone_number, message)
    caption_available = true
    message.attachments.map do |attachment|
      type = attachment_type(attachment)
      content = { link: attachment.download_url }
      if caption_available && message.outgoing_content.present? && %w[image video document].include?(type)
        content[:caption] = message.outgoing_content
        caption_available = false
      end
      content[:filename] = attachment.file.filename.to_s if type == 'document'

      payload = base_payload(phone_number, type).merge(
        context: reply_context(message),
        externalId: external_id(message, attachment)
      )
      payload[type.to_sym] = content
      payload.compact
    end
  end

  def interactive_payload(phone_number, message)
    items = message.content_attributes['items']
    interactive = if items.length <= 3
                    {
                      type: 'button',
                      body: { text: message_content(message) },
                      action: {
                        buttons: items.map { |item| { type: 'reply', reply: { id: item['value'], title: item['title'] } } }
                      }
                    }
                  else
                    {
                      type: 'list',
                      body: { text: message_content(message) },
                      action: {
                        button: I18n.t('conversations.messages.whatsapp.list_button_label'),
                        sections: [{ rows: items.map { |item| { id: item['value'], title: item['title'] } } }]
                      }
                    }
                  end

    base_payload(phone_number, 'interactive').merge(
      interactive: interactive,
      context: reply_context(message),
      externalId: external_id(message)
    ).compact
  end

  def attachment_type(attachment)
    return 'image' if attachment.file_type == 'image'
    return 'audio' if attachment.file_type == 'audio'
    return 'video' if attachment.file_type == 'video'

    'document'
  end

  def external_id(message, attachment = nil)
    [message.id, attachment&.id].compact.join(':')
  end

  def persist_send_result(message, message_ids, errors)
    if message_ids.blank?
      error = errors.compact_blank.join('; ').presence || 'YCloud did not return a message ID'
      message.update!(status: :failed, external_error: error)
      return
    end

    attributes = message.additional_attributes.to_h.merge(
      'ycloud_message_ids' => message_ids,
      'ycloud_delivery_statuses' => message_ids.index_with { 'sent' }
    )
    attributes['ycloud_send_errors'] = errors if errors.present?
    error = errors.compact_blank.join('; ').presence
    message.update!(
      additional_attributes: attributes,
      status: error.present? ? :failed : :sent,
      external_error: error
    )
  end

  def reply_context(message)
    external_id = message.content_attributes['in_reply_to_external_id']
    return if external_id.blank?

    { message_id: external_id }
  end

  def response_message_id(response)
    parsed_response = response.parsed_response || {}
    return parsed_response['id'].presence || parsed_response['wamid'] if response.success? && parsed_response['error'].blank?
  end

  def response_error(response)
    parsed_response = response.parsed_response
    return if response.success? && parsed_response.to_h['error'].blank?

    parsed_response&.dig('error', 'message').presence || "YCloud HTTP #{response.code}"
  end

  def waba_id
    whatsapp_channel.provider_config['waba_id']
  end

  def api_base_path
    ENV.fetch('YCLOUD_API_BASE_URL', 'https://api.ycloud.com/v2/whatsapp')
  end
end
