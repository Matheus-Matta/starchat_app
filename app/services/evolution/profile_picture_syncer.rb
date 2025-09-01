# app/services/evolution/profile_picture_syncer.rb
require 'open-uri'
require 'securerandom'  # <— add

class Evolution::ProfilePictureSyncer
  include ::Evolution::WaUtils  
  DEFAULT_ATTR_KEY = 'wa_profile_pic_url'

  def self.call(contact, url, attr_key: DEFAULT_ATTR_KEY, attach: true)
    return if contact.blank? || url.blank?

    save_url(contact, attr_key, url)

    return unless attach &&
                  contact.respond_to?(:avatar) &&
                  contact.avatar.respond_to?(:attach)

    current = (contact.respond_to?(:additional_attributes) ? contact.additional_attributes : contact.try(:custom_attributes)) || {}
    return if current[attr_key] == url && contact.avatar.attached?

    URI.open(url, open_timeout: 3, read_timeout: 5) do |io|
      content_type = io.respond_to?(:content_type) ? io.content_type : 'image/jpeg'
      contact.avatar.attach(
        io: io,
        filename: "wa_#{SecureRandom.hex(8)}#{file_ext(io)}",
        content_type: content_type
      )
    end
  rescue => e
    Rails.logger.warn "[Evolution] ProfilePictureSyncer failed (Contact##{contact&.id}): #{e.class} #{e.message}"
  end
end
