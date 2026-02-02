# frozen_string_literal: true

class Evolution::MessageBaseService < Whatsapp::IncomingMessageBaseService
  include FileTypeHelper
  include ::DownloadForWhatsappEnc

  include Evolution::DownloadForBase64
  include Evolution::MediaAttach
  include Evolution::MessageReplyTo
  include Evolution::ConversationEnsurer

  def initialize(inbox:, processed:)
    @inbox     = inbox
    @processed = processed.respond_to?(:with_indifferent_access) ? processed.with_indifferent_access : processed
  end

  MediaDownload = Struct.new(:io, :path, :filename, :content_type)

  private

  attr_reader :inbox, :processed

  def processed_params
    @processed
  end

  def locked_name?(contact)
    contact.custom_attributes&.dig('lock_name') == true
  end

  def ensure_contact_from_message!(message)
    jid        = Evolution::MessageHelpers.remote_jid_from(message)
    phone_e164 = Evolution::MessageHelpers.e164_from_jid(jid)
    return if phone_e164.blank?

    waid = phone_e164.delete_prefix('+')
    sender_is_me = Evolution::MessageHelpers.from_me?(message)
    display = Evolution::MessageHelpers.push_name_from(message).presence
    desired = sender_is_me ? phone_e164 : (display || phone_e164)

    ci = ::ContactInboxWithContactBuilder.new(
      source_id: waid,
      inbox: inbox,
      contact_attributes: {
        name: desired,
        phone_number: "+#{waid}"
      }
    ).perform

    @contact        = ci.contact
    @contact_inbox  = ci

    if !sender_is_me && !locked_name?(@contact) && display.present?
      unless looks_like_number?(display)
        current_name = @contact.name.to_s
        is_current_placeholder = current_name.blank? || looks_like_number?(current_name)

        @contact.update(name: display) if is_current_placeholder || (current_name != display)
      end
    elsif sender_is_me && @contact.name.blank? && !locked_name?(@contact)
      @contact.update_columns(name: phone_e164, updated_at: Time.current)
    end

    pic_url = message['profilePicUrl'] || message.dig('key', 'profilePicUrl')
    update_contact_avatar(@contact, pic_url) if pic_url.present?

    @contact
  end

  def update_contact_avatar(contact, url)
    return if url.blank?

    current_url = begin
      contact.additional_attributes['wa_profile_pic_url']
    rescue StandardError
      nil
    end
    return if current_url == url

    contact.additional_attributes['wa_profile_pic_url'] = url
    contact.save

    Avatar::AvatarFromUrlJob.perform_later(contact, url)
  end

  def looks_like_number?(str)
    return false if str.blank?

    clean = str.to_s.gsub(/[\s\-\(\)\+]/, '')
    clean.match?(/\A\d+\z/) && clean.length >= 7
  end
end
