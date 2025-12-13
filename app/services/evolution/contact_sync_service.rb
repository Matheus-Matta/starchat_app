# frozen_string_literal: true
require 'down'
require 'uri'

class Evolution::ContactSyncService
  include ::Whatsapp::IncomingMessageServiceHelpers

  def initialize(inbox:, list:)
    @inbox = inbox
    @list  = Array(list)
  end

  def perform
    @list.each do |c|

      phone_e164 = e164_from_jid(c['remoteJid'])
      next if phone_e164.blank?

      waid      = processed_waid(phone_e164.delete_prefix('+'))
      push_name = extract_push_name(c) # pode ser nil
      pic_url   = extract_profile_pic_url(c)

      initial_name =
        if push_name.present? && !name_is_number?(push_name)
          push_name
        else
          phone_e164 
        end

      contact_inbox = ::ContactInboxWithContactBuilder.new(
        source_id: waid,
        inbox:     @inbox,
        contact_attributes: { name: initial_name, phone_number: "+#{waid}" }
      ).perform

      contact = contact_inbox.contact
      if contact.name.blank? && push_name.present? && !name_is_number?(push_name)
        contact.update!(name: push_name)
      elsif name_is_number?(contact.name) && push_name.present? && !name_is_number?(push_name)
        contact.update!(name: push_name)
      else
      end

      sync_profile_image_like_whatsapp!(contact, pic_url) if pic_url.present?
    rescue => e
      Rails.logger.warn "[Evolution] contact sync row failed: #{e.class} #{e.message}"
    end
  end

  private

  attr_reader :inbox

  def e164_from_jid(remote_jid)
    return if remote_jid.blank?
    number = remote_jid.to_s.split('@').first.to_s.split(':').first
    return if number.blank? || number !~ /\A\d+\z/
    "+#{number}"
  end

  def extract_push_name(c)
    c['pushName'].presence
  end

  def extract_profile_pic_url(c)
    c['profilePicUrl'].presence
  end

  def sync_profile_image_like_whatsapp!(contact, url)
    return if url.blank?

    attrs   = (contact.additional_attributes || {}).dup
    customs = (contact.custom_attributes || {}).dup
    attrs['wa_profile_pic_url']   = url
    customs['wa_profile_pic_url'] = url

    Contact.transaction do
      contact.update_columns(
        additional_attributes: attrs,
        custom_attributes:     customs,
        updated_at:            Time.current
      )
    end
  end

  def name_is_number?(name)
    return false if name.blank?
    normalized = name.gsub(/\s+/, '')
    normalized.match?(/\A\+?\d+\z/)
  end
end
