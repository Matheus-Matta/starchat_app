# app/services/evolution/incoming_message_service.rb
# frozen_string_literal: true
require 'base64'
require 'stringio'
require 'mime/types'

class Evolution::IncomingMessageService
  def initialize(inbox:, raw_message:)
    @inbox = inbox
    @raw   = raw_message.with_indifferent_access
  end

  def perform
    return unless @inbox && @inbox.account&.active?

    from_me    = !!@raw.dig(:key, :fromMe)
    remote_jid = Evolution::WaUtils.extract_remote_jid(@raw)
    return unless Evolution::WaUtils.phone_jid?(remote_jid)

    push_name  = Evolution::WaUtils.extract_push_name(@raw)
    pic_url    = Evolution::WaUtils.profile_pic_url(@raw)

    contact_inbox, contact = Evolution::WaUtils.find_or_create_contact_inbox!(
      account:    @inbox.account,
      inbox:      @inbox,
      remote_jid: remote_jid,
      push_name:  push_name,
      profile_pic: pic_url
    )

    conversation = Evolution::WaUtils.find_or_open_conversation!(
      account: @inbox.account,
      inbox:   @inbox,
      contact_inbox: contact_inbox
    )

    source_id = @raw.dig(:key, :id).presence
    return if source_id.present? && Message.exists?(inbox_id: @inbox.id, source_id: source_id)

    text, attachment_attrs = extract_payload(@raw)

    msg = conversation.messages.build(
      account_id:   conversation.account_id,
      inbox_id:     conversation.inbox_id,
      message_type: (from_me ? :outgoing : :incoming),
      content:      text,
      content_type: 'text',
      sender:       (from_me ? nil : contact),
      source_id:    source_id,
      created_at:   timestamp_from(@raw[:timestamp] || @raw[:messageTimestamp])
    )
    msg.save!

    attach_base64!(msg, **attachment_attrs) if attachment_attrs.present?
    msg
  end

  private

  def extract_payload(raw)
    text =
      raw.dig(:message, :conversation) ||
      raw.dig(:message, :extendedTextMessage, :text) ||
      raw[:text] ||
      raw[:caption]

    media_info =
      raw.dig(:message, :imageMessage)    ||
      raw.dig(:message, :videoMessage)    ||
      raw.dig(:message, :documentMessage) ||
      raw.dig(:message, :audioMessage)    ||
      {}

    base64   = media_info[:base64]   || raw[:base64]
    mimetype = media_info[:mimetype] || raw[:mimetype]
    filename = media_info[:fileName] || raw[:fileName]
    caption  = media_info[:caption]  || raw[:caption]

    attachment_attrs =
      if base64.present? && mimetype.present?
        { base64: base64, mimetype: mimetype, filename: (filename.presence || default_filename_for(mimetype)), caption: caption }
      else
        {}
      end

    [text, attachment_attrs]
  end

  def default_filename_for(mime)
    ext = MIME::Types[mime].first&.preferred_extension || 'bin'
    "file.#{ext}"
  rescue
    'file.bin'
  end

  def attach_base64!(message, base64:, mimetype:, filename:, caption: nil)
    data = Base64.decode64(base64.to_s)
    io   = StringIO.new(data)
    io.set_encoding(Encoding::BINARY)

    attachment = message.attachments.build(account_id: @inbox.account_id)
    attachment.file.attach(io: io, filename: filename, content_type: mimetype)
    attachment.save!

    message.update!(content: caption) if caption.present? && message.content.to_s.blank?
  end

  def timestamp_from(ts)
    return Time.zone.at(ts.to_i) if ts.present?
    Time.zone.now
  end
end
