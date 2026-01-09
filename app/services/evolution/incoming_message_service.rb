# frozen_string_literal: true
require 'securerandom'

class Evolution::IncomingMessageService < Evolution::MessageBaseService
  attr_reader :payload

  def perform
    @payload = processed_params.is_a?(Hash) ? processed_params : {}
    return if @payload.blank?

    ensure_contact_from_message!(@payload)
    @conversation = Evolution::ConversationEnsurer.ensure!(inbox:, contact_inbox: @contact_inbox)
    create_message
  end

  private

  def create_message

    source_id = (@payload.dig('key', 'id') || @payload['messageId']).to_s
    if ::Message.exists?(inbox_id: inbox.id, source_id: source_id)
      return
    end

    if Evolution::MessageReaction.apply!(
        inbox_id:   inbox.id,
        payload:    @payload,
        author_name: (@contact&.name.presence || @payload['pushName'])
      )
      return
    end

    outgoing = Evolution::MessageHelpers.from_me?(@payload)
    text     = extract_text(@payload).to_s

    attached = attach_from_payload!(@message ||= temp_message_shell(outgoing, source_id), @payload)
    Rails.logger.info("[EVOLUTION INCOMING] source_id=#{source_id} text=#{text.inspect} attached=#{attached.inspect}")

    if text.blank? && !attached
      Rails.logger.warn("[EVOLUTION INCOMING] ABORT: text blank and no attachments. Payload: #{@payload.keys}")
      return
    end

    @message.content = text
    Evolution::MessageReplyTo.apply!(@message, @payload)

    if @message.save
      Rails.logger.info("[EVOLUTION INCOMING] Message created successfully id=#{@message.id}")
      @message.attachments.each do |att|
        blob = att.file.blob
      end
    else
      Rails.logger.error("[EVOLUTION INCOMING] Failed to save message: #{@message.errors.full_messages}")
    end
  end

  def temp_message_shell(outgoing, source_id)
    attrs = {
      content:                 '', 
      account_id:              inbox.account_id,
      inbox_id:                inbox.id,
      message_type:            outgoing ? :outgoing : :incoming,
      source_id:               source_id,
      in_reply_to_external_id: nil
    }
    outgoing ? @conversation.messages.build(attrs) :
               @conversation.messages.build(attrs.merge(sender: @contact))
  end

  def extract_media_debug(p)
    p.dig('message', 'audioMessage') ||
      p.dig('message', 'videoMessage') ||
      p.dig('message', 'imageMessage') ||
      p.dig('message', 'documentMessage')
  end

  def extract_text(p)
    p.dig('message', 'conversation') ||
      p.dig('message', 'extendedTextMessage', 'text') ||
      p.dig('message', 'imageMessage', 'caption') ||
      p.dig('message', 'videoMessage', 'caption') ||
      p.dig('message', 'documentMessage', 'caption') ||
      ''
  end

end
