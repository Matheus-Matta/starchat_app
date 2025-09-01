# frozen_string_literal: true
class Evolution::WarmupChatService
  def initialize(inbox:, list:)
    @inbox = inbox
    @list  = Array(list)
  end

  def perform
    @list.each do |row|
      h   = row.with_indifferent_access
      jid = Evolution::WaUtils.extract_remote_jid(h)
      next unless Evolution::WaUtils.phone_jid?(jid)

      ci, _contact = Evolution::WaUtils.find_or_create_contact_inbox!(
        account:    @inbox.account,
        inbox:      @inbox,
        remote_jid: jid
      )

      Evolution::WaUtils.find_or_open_conversation!(
        account: @inbox.account,
        inbox:   @inbox,
        contact_inbox: ci
      )
    rescue => e
      Rails.logger.warn "[Evolution] warmup chat row failed: #{e.class} #{e.message}"
    end
  end
end
