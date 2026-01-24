# frozen_string_literal: true

module Evolution::CommonHelpers
  extend ActiveSupport::Concern

  def create_connection_change_notification(inbox, status = 'disconnected')
    recipients = inbox.account.administrators
    recipients = inbox.members if recipients.blank?

    return if recipients.blank?

    recipients.uniq.each do |admin|
      # De-duplicate: don't create if one exists for the same user/inbox AND same status in the last 2 minutes
      # This allows "close" then "open" to both notify, but blocks repeated "close"
      next if Notification.where(
        user: admin,
        notification_type: 'inbox_connection_update',
        primary_actor: inbox,
        created_at: 2.minutes.ago..Time.current
      ).exists?(["meta ->> 'status' = ?", status])

      Notification.create!(
        notification_type: 'inbox_connection_update',
        account: inbox.account,
        user: admin,
        primary_actor: inbox,
        meta: { status: status }
      )
    rescue StandardError => e
      Rails.logger.error("[Evolution] Failed to create notification for user #{admin.id}: #{e.message}")
    end
  end

  def extract_qr(resp)
    h = to_hash(resp)
    q = h['qrcode'] || h.dig('data', 'qrcode') || {}
    # Removed h.dig('instance', 'qrcode') because 'instance' is often a String ID, causing TypeError

    base64 = q['base64'] || h['base64'] || h.dig('data', 'base64')
    pair   = q['pairingCode'] || h['pairingCode'] || h.dig('data', 'pairingCode')

    { base64: base64, pairing_code: pair }.compact
  end

  def to_hash(resp)
    return resp if resp.is_a?(Hash)
    return JSON.parse(resp) if resp.is_a?(String)

    {}
  rescue JSON::ParserError
    {}
  end

  def read_instance_state(h)
    (h.dig('instance', 'state') || h['state']).to_s.downcase
  end
end
