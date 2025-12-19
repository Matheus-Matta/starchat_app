# app/services/evolution/send_message_service.rb
# frozen_string_literal: true
require 'uri'
require 'base64'

class Evolution::SendMessageService
  include Evolution::StatusUpdate

  MEDIA_ORDER = %i[image video audio document].freeze

  def initialize(message:, channel: nil)
    @message      = message
    @conversation = message.conversation
    @inbox        = @conversation.inbox
    @channel      = channel || @inbox.channel
    @evolution_message_id = nil
  end

  def perform
    return unless evolution_channel?
    return unless dispatchable?

    if already_dispatched? || @message.delivered? || @message.read?
      Rails.logger.info("[Evolution::SendMessageService] skip: message #{message.id} already dispatched (source_id=#{message.source_id.inspect}, status=#{message.status})")
      return
    end

    client   = build_client
    number   = recipient_waid
    instance = @channel.instance_name

    quoted = safely_build_quoted_for(@message)

    any_success = false

    if @message.content.present?
      begin
        resp = client.send_text(instance, number: number, text: @message.content.to_s, quoted: quoted)
        persist_message_id_from(resp)
        any_success = true
      rescue Evolution::Client::Error => e
        record_send_error!(error: e, kind: :text, payload: { number:, instance:, quoted_present: quoted.present? })
        return
      rescue => e
        record_send_error!(error: e, kind: :text, payload: { number:, instance:, quoted_present: quoted.present? })
        return
      end
    end

    ordered_attachments.each do |att|
      kind     = file_kind(att)
      url      = active_storage_url(att.file.blob, expires_in: media_url_ttl)
      mimetype = att.file.content_type
      fname    = att.file.filename.to_s

      begin
        if kind == :audio
          audio_b64 = encode_blob_base64(att.file.blob)

          resp = client.send_whatsapp_audio(
            instance,
            number: number,
            audio:  audio_b64,  
            delay:  0,
            quoted: quoted
          )
        else
          base64_data = encode_blob_base64(att.file.blob)

          mediatype = case kind
                      when :image then 'image'
                      when :video then 'video'
                      else              'document'
                      end
          opts = { mimetype: mimetype, quoted: quoted }
          opts[:file_name] = fname if mediatype == 'document'
          resp = client.send_media(instance, number: number, mediatype: mediatype, media: base64_data, **opts)
        end

        persist_message_id_from(resp)
        any_success = true

      rescue Evolution::Client::Error => e
        record_send_error!(error: e, kind: kind, payload: { number:, instance:, url:, mimetype:, fname:, quoted_present: quoted.present? })
      rescue => e
        record_send_error!(error: e, kind: kind, payload: { number:, instance:, url:, mimetype:, fname:, quoted_present: quoted.present? })
      end
    end

    if any_success
      mark_dispatched!
      update_message_status!(message: @message, status: 'delivered', external_error: nil)
    end

  rescue Evolution::Client::Error => e
    Rails.logger.error "[Evolution::SendMessageService] API error: #{e.message}"
    raise
  rescue => e
    Rails.logger.error "[Evolution::SendMessageService] #{e.class}: #{e.message}"
    raise
  end

  private

  attr_reader :message

  def evolution_channel?
    @channel.is_a?(::Channel::Evolution)
  end

  def dispatchable?
    # Only send outgoing messages that are NOT private
    # Private messages (internal notes, system errors) should NEVER go to the client
    @message.outgoing? && !@message.private?
  end

  def already_dispatched?
    @message.source_id.present? || @message.additional_attributes.to_h['evolution_dispatched']
  end

  def build_client
    Evolution::Client.new(
      base_url: ENV.fetch('EVOLUTION_BASE_URL'),
      api_key:  @channel.api_key.presence || ENV.fetch('EVOLUTION_API_KEY')
    )
  end

  def recipient_waid
    @conversation.contact_inbox.source_id
  end

  def ordered_attachments
    @message.attachments.to_a.sort_by { |att| MEDIA_ORDER.index(file_kind(att)) || 99 }
  end

  def file_kind(att)
    ct = att.file.content_type.to_s
    return :image if ct.start_with?('image/')
    return :video if ct.start_with?('video/')
    return :audio if ct.start_with?('audio/')
    :document
  end

  def active_storage_url(blob, expires_in: 15.minutes)
    if blob.respond_to?(:url) # Rails 7.1+
      blob.url(expires_in: expires_in, disposition: 'inline', filename: blob.filename)
    else
      blob.service_url(expires_in: expires_in, disposition: 'inline', filename: blob.filename)
    end
  end

  def media_url_ttl
    Integer(ENV.fetch("EVOLUTION_MEDIA_URL_TTL_SECONDS", 900))
  end

  def build_quoted_for(message)
    attrs = message.content_attributes.to_h

    external_id = attrs['in_reply_to_external_id'].presence

    parent = message.respond_to?(:in_reply_to) ? message.in_reply_to : nil
    parent = Message.find_by(id: parent) if parent.is_a?(Integer) || parent.is_a?(String)
    parent ||= Message.find_by(id: attrs['in_reply_to']) if attrs['in_reply_to'].present?

    if external_id.blank? && parent.present?
      parent_attrs = parent.respond_to?(:content_attributes) ? parent.content_attributes.to_h : {}
      external_id  = parent.source_id.presence || parent_attrs['external_id'].presence
    end

    return nil if external_id.blank?

    remote_jid =
      parent&.conversation&.contact_inbox&.source_id ||
      message.conversation.contact_inbox.source_id
    remote_jid = "#{remote_jid}@s.whatsapp.net" if remote_jid.present? && !remote_jid.include?('@')

    from_me = parent.present? ? parent.outgoing? : false

    preview =
      attrs['quoted_preview'].presence ||
      (parent.content.to_s if parent.respond_to?(:content))

    if preview.present?
      preview = preview.gsub(/\R+/, ' ').strip
      preview = preview[0, 240] if preview.length > 240
    end

    q = {
      'key' => {
        'id'        => external_id,
        'remoteJid' => remote_jid,
        'fromMe'    => from_me
      }
    }
    q['message'] = { 'conversation' => preview } if preview.present?
    q
  end

  def safely_build_quoted_for(message)
    build_quoted_for(message)
  rescue => e
    Rails.logger.warn("[Evolution] build_quoted_for failed: #{e.class}: #{e.message}")
    nil
  end

  def persist_message_id_from(resp)
    return if @evolution_message_id.present?

    eid = extract_message_id(resp)
    return if eid.blank?

    @evolution_message_id = eid
    @message.update!(source_id: eid)
    Rails.logger.info("[Evolution] linked message #{@message.id} to source_id=#{eid}")
  end

  def extract_message_id(resp)
    h = resp.is_a?(Hash) ? resp : (JSON.parse(resp) rescue {})
    h.dig('key', 'id') ||
      h['messageId'] ||
      h.dig('data', 'messageId') ||
      h['id'] ||
      h.dig('data', 'id')
  end

  def mark_dispatched!
    h = @message.additional_attributes.to_h
    h['evolution_dispatched'] = true
    @message.update_columns(additional_attributes: h, updated_at: Time.current)
  end

  def record_send_error!(error:, kind:, payload: {})
    Rails.logger.error "[Evolution::SendMessageService] send_#{kind} error: #{error.class}: #{error.message}"

    update_message_status!(message: @message, status: 'failed', external_error: error.message)
  end

  def encode_blob_base64(blob)
    if blob.respond_to?(:open)
      blob.open { |io| Base64.strict_encode64(io.read) }
    else
      Base64.strict_encode64(blob.download)
    end
  end
end
