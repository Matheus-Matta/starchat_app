class Webhooks::YcloudController < ActionController::API
  def process_payload
    payload = JSON.parse(request.raw_post)
    channel = find_channel(payload)
    if channel.blank?
      Rails.logger.warn("[YCLOUD] Webhook #{payload['id']} does not match an installed channel")
      return head :ok
    end
    return head :unauthorized unless valid_signature?(channel)

    Webhooks::YcloudEventsJob.perform_later(channel.id, payload)
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def find_channel(payload)
    event_payload = payload['whatsappInboundMessage'] || payload['whatsappMessage'] || {}
    channel_from_external_id = find_channel_from_external_id(event_payload['externalId'])
    return channel_from_external_id if channel_from_external_id.present?

    waba_id = event_payload['wabaId']
    return if waba_id.blank?

    business_phone_number = if payload['type'] == 'whatsapp.inbound_message.received'
                              event_payload['to']
                            else
                              event_payload['from']
                            end

    channels = Channel::Whatsapp.includes(:account).where(provider: 'ycloud')
                                .where("provider_config ->> 'waba_id' = ?", waba_id.to_s)
                                .select(&:ycloud_feature_enabled?)
    matching_channel = channels.find do |channel|
      normalized_phone(channel.phone_number) == normalized_phone(business_phone_number)
    end
    return matching_channel if matching_channel.present?

    channels.first if channels.one?
  end

  def find_channel_from_external_id(external_id)
    message_id = external_id.to_s.split(':').first
    return if message_id.blank?

    channel = Message.find_by(id: message_id)&.inbox&.channel
    return unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'ycloud' && channel.ycloud_feature_enabled?

    channel
  end

  def valid_signature?(channel)
    secret = channel.provider_config['webhook_secret']
    signature_header = request.headers['YCloud-Signature']
    return false if secret.blank? || signature_header.blank?

    parts = signature_header.split(',').to_h { |part| part.split('=', 2) }
    timestamp = parts['t']
    signature = parts['s']
    return false if timestamp.blank? || signature.blank?
    # YCloud retries failed deliveries for several hours. Keep the signature
    # window wide enough for the documented retry schedule; event IDs provide
    # the stricter replay protection after a delivery has been accepted.
    return false if (Time.current.to_i - timestamp.to_i).abs > 6.hours

    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{request.raw_post}")
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  def normalized_phone(phone_number)
    phone_number.to_s.gsub(/\D/, '')
  end
end
