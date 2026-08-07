class Webhooks::YcloudEventsJob < ApplicationJob
  queue_as :low
  retry_on CustomExceptions::YcloudWebhookDependencyNotReady, wait: 5.seconds, attempts: 12

  def perform(channel_id, payload)
    @event_acquired = acquire_event(payload['id'])
    return unless @event_acquired

    channel = Channel::Whatsapp.find_by(id: channel_id, provider: 'ycloud')
    channel = nil unless channel&.ycloud_feature_enabled?
    if channel.present?
      case payload['type']
      when 'whatsapp.inbound_message.received'
        process_inbound(channel, payload['whatsappInboundMessage'])
      when 'whatsapp.message.updated'
        process_status(channel, payload['whatsappMessage'])
      when 'whatsapp.smb.message.echoes'
        process_echo(channel, payload['whatsappMessage'])
      end
    end

    mark_event_processed(payload['id'])
  rescue StandardError
    release_event(payload['id']) if @event_acquired
    raise
  end

  private

  def process_inbound(channel, message)
    return if message.blank?
    return reject_group_message(channel, message) if message['groupId'].present?
    return process_reaction(channel, message) if message['type'] == 'reaction'

    params = cloud_api_payload(channel, message).with_indifferent_access
    Whatsapp::IncomingMessageYcloudService.new(inbox: channel.inbox, params: params).perform
    channel.provider_service.mark_message_as_read(message['id'])
  end

  def process_status(channel, message)
    return if message.blank?

    local_message = find_local_message(channel, message)
    if local_message.blank?
      if message['externalId'].present?
        raise CustomExceptions::YcloudWebhookDependencyNotReady,
              "YCloud message #{message['externalId']} is not available yet"
      end

      Rails.logger.info("[YCLOUD] Ignoring status for unknown message #{message['id']}")
      return
    end

    send_errors = local_message.additional_attributes.to_h.fetch('ycloud_send_errors', [])
    statuses = local_message.additional_attributes.to_h.fetch('ycloud_delivery_statuses', {})
    statuses[message['id']] = next_delivery_status(statuses[message['id']], message['status'])
    delivery_errors = local_message.additional_attributes.to_h.fetch('ycloud_delivery_errors', {})
    update_delivery_errors(delivery_errors, message)
    wamids = merge_wamid(local_message, message)
    attributes = local_message.additional_attributes.to_h.merge(
      'ycloud_delivery_statuses' => statuses,
      'ycloud_delivery_errors' => delivery_errors,
      'ycloud_wamids' => wamids,
      'ycloud_wamid_values' => wamids.values
    )
    local_message.update!(additional_attributes: attributes)

    status = aggregate_status(statuses.values, send_errors)
    error = (send_errors + delivery_errors.values).compact_blank.join('; ').presence
    Messages::StatusUpdateService.new(local_message, status, error).perform
    update_campaign_contact(local_message, status, error)
  end

  def process_echo(channel, message)
    return if message.blank?

    params = echo_payload(channel, message).with_indifferent_access
    Whatsapp::IncomingMessageYcloudService.new(inbox: channel.inbox, params: params, outgoing_echo: true).perform
  end

  def process_reaction(channel, message)
    result = Ycloud::MessageReactionService.new(channel: channel, payload: message).perform
    if result == :parent_not_found
      raise CustomExceptions::YcloudWebhookDependencyNotReady,
            "YCloud reaction parent #{message.dig('reaction', 'message_id')} is not available yet"
    end

    channel.provider_service.mark_message_as_read(message['id'])
  end

  def reject_group_message(channel, message)
    Rails.logger.warn(
      "[YCLOUD] Ignoring unsupported group message #{message['id']} for inbox #{channel.inbox.id} (group #{message['groupId']})"
    )
  end

  def cloud_api_payload(channel, message)
    {
      'object' => 'whatsapp_business_account',
      'entry' => [{
        'changes' => [{
          'field' => 'messages',
          'value' => {
            'metadata' => metadata(channel),
            'contacts' => [{
              'wa_id' => normalized_phone(message['from']),
              'user_id' => message['fromUserId'],
              'parent_user_id' => message['fromParentUserId'],
              'profile' => {
                'name' => message.dig('customerProfile', 'name'),
                'username' => message.dig('customerProfile', 'username')
              }.compact
            }],
            'messages' => [normalized_message(message)]
          }
        }]
      }]
    }
  end

  def echo_payload(channel, message)
    {
      'object' => 'whatsapp_business_account',
      'entry' => [{
        'changes' => [{
          'field' => 'smb_message_echoes',
          'value' => {
            'metadata' => metadata(channel),
            'message_echoes' => [normalized_echo(message)]
          }
        }]
      }]
    }
  end

  def normalized_message(message)
    type = message['type']
    return normalized_flow_message(message) if type == 'interactive' && message.dig('interactive', 'type') == 'nfm_reply'
    return normalized_voice_message(message) if type == 'voice'
    return normalized_unsupported_message(message) unless supported_message_type?(type)

    normalized = {
      from: normalized_phone(message['from']),
      from_user_id: message['fromUserId'],
      from_parent_user_id: message['fromParentUserId'],
      id: message['wamid'].presence || message['id'],
      timestamp: event_timestamp(message['sendTime']),
      type: type,
      context: normalize_context(message['context'])
    }
    normalized[type.to_sym] = message[type]
    normalized.compact
  end

  def normalized_flow_message(message)
    response = message.dig('interactive', 'response_json')
    body = response.presence || message.dig('interactive', 'body').presence || 'Flow response'
    {
      from: normalized_phone(message['from']),
      from_user_id: message['fromUserId'],
      from_parent_user_id: message['fromParentUserId'],
      id: message['wamid'].presence || message['id'],
      timestamp: event_timestamp(message['sendTime']),
      type: 'text',
      text: { body: body },
      context: normalize_context(message['context'])
    }.compact
  end

  def normalized_voice_message(message)
    normalized_message(message.merge('type' => 'audio', 'audio' => message['voice']))
  end

  def normalized_unsupported_message(message)
    {
      from: normalized_phone(message['from']),
      from_user_id: message['fromUserId'],
      from_parent_user_id: message['fromParentUserId'],
      id: message['wamid'].presence || message['id'],
      timestamp: event_timestamp(message['sendTime']),
      type: 'unsupported',
      context: normalize_context(message['context'])
    }.compact
  end

  def normalized_echo(message)
    normalized_message(message).merge(
      from: normalized_phone(message['from']),
      to: normalized_phone(message['to']),
      to_user_id: message['toUserId'],
      to_parent_user_id: message['toParentUserId']
    )
  end

  def normalize_context(context)
    return if context.blank?

    { id: context['message_id'].presence || context['id'] }
  end

  def metadata(channel)
    {
      display_phone_number: channel.phone_number.delete_prefix('+'),
      phone_number_id: channel.provider_config['phone_number_id']
    }.compact
  end

  def normalized_phone(phone_number)
    phone_number.to_s.gsub(/\D/, '')
  end

  def supported_message_type?(type)
    %w[text image audio video document sticker location contacts button interactive unsupported request_welcome].include?(type)
  end

  def event_timestamp(value)
    Time.zone.parse(value.to_s)&.to_i&.to_s || Time.current.to_i.to_s
  end

  def find_local_message(channel, payload)
    external_id = payload['externalId'].to_s.split(':').first
    return channel.inbox.messages.find_by(id: external_id) if external_id.present?

    channel.inbox.messages.find_by(source_id: payload['id'])
  end

  def aggregate_status(statuses, send_errors = [])
    return 'failed' if send_errors.present? || statuses.include?('failed')
    return 'read' if statuses.all?('read')
    return 'delivered' if statuses.all? { |status| %w[delivered read].include?(status) }
    return 'sent' if statuses.include?('sent')
    return 'read' if statuses.include?('read')
    return 'delivered' if statuses.include?('delivered')

    'sent'
  end

  def next_delivery_status(current_status, new_status)
    return new_status if current_status.blank?
    return current_status if current_status == 'read'
    return current_status if current_status == 'delivered' && %w[sent failed].include?(new_status)
    return current_status if current_status == 'failed' && new_status == 'sent'

    new_status
  end

  def update_delivery_errors(delivery_errors, payload)
    if payload['status'] == 'failed'
      delivery_errors[payload['id']] = [
        payload['errorCode'],
        payload['errorMessage'],
        payload.dig('whatsappApiError', 'error_data', 'details')
      ].compact_blank.join(': ')
    else
      delivery_errors.delete(payload['id'])
    end
  end

  def merge_wamid(message, payload)
    wamids = message.additional_attributes.to_h.fetch('ycloud_wamids', {})
    wamids[payload['id']] = payload['wamid'] if payload['wamid'].present?
    wamids
  end

  def acquire_event(event_id)
    return true if event_id.blank?

    key = event_key(event_id)
    return false if Redis::Alfred.get(key) == 'processed'

    acquired = Redis::Alfred.set(key, 'processing', nx: true, ex: 2.minutes)
    raise CustomExceptions::YcloudWebhookDependencyNotReady, "YCloud event #{event_id} is already being processed" unless acquired

    true
  end

  def mark_event_processed(event_id)
    return if event_id.blank?

    Redis::Alfred.set(event_key(event_id), 'processed', ex: 7.days)
  end

  def release_event(event_id)
    return if event_id.blank?

    Redis::Alfred.delete(event_key(event_id))
  end

  def update_campaign_contact(message, status, error)
    campaign_contact_id = message.additional_attributes.to_h['campaign_contact_id']
    return if campaign_contact_id.blank?

    campaign_contact = CampaignContact.find_by(id: campaign_contact_id)
    return if campaign_contact.blank?

    if status == 'failed'
      campaign_contact.update!(status: :failed, error_message: error)
    else
      campaign_contact.update!(status: :sent, sent_at: campaign_contact.sent_at || Time.current, error_message: nil)
    end
  end

  def event_key(event_id)
    "ycloud:webhook:event:#{event_id}"
  end
end
