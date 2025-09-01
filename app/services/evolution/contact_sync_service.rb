# frozen_string_literal: true
class Evolution::ContactSyncService
  def initialize(inbox:, list:)
    @inbox = inbox
    @list  = Array(list)
  end

  def perform
    @list.each do |row|
      h   = row.with_indifferent_access
      jid = Evolution::WaUtils.extract_remote_jid(h)
      next unless Evolution::WaUtils.phone_jid?(jid)

      push = Evolution::WaUtils.extract_push_name(h)
      pic  = Evolution::WaUtils.profile_pic_url(h)

      ci, contact = Evolution::WaUtils.find_or_create_contact_inbox!(
        account:    @inbox.account,
        inbox:      @inbox,
        remote_jid: jid,
        push_name:  push,
        profile_pic: pic
      )

      contact.update!(name: push) if contact.name.blank? && push.present?
    rescue => e
      Rails.logger.warn "[Evolution] contact sync row failed: #{e.class} #{e.message}"
    end
  end
end
