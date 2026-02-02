# frozen_string_literal: true

module Evolution::CommonHelpers
  extend ActiveSupport::Concern

  def create_connection_change_notification(inbox, status = 'disconnected')
    send_evolution_notification(
      inbox: inbox,
      type: 'inbox_connection_update',
      meta: { status: status },
      dedup_key: 'status',
      dedup_value: status,
      dedup_window: 2.minutes
    )
  end

  def create_incoming_call_notification(inbox, from_number)
    send_evolution_notification(
      inbox: inbox,
      type: 'incoming_call',
      meta: { from_number: from_number },
      dedup_key: 'from_number',
      dedup_value: from_number,
      dedup_window: 1.minute
    )
  end

  private

  def send_evolution_notification(inbox:, type:, meta:, dedup_key:, dedup_value:, dedup_window:)
    # Prioritize inbox members (agents working on it)
    recipients = inbox.members
    # Fallback to admins if no specific members assigned
    recipients = inbox.account.administrators if recipients.blank?

    return if recipients.blank?

    recipients.uniq.each do |user|
      # Deduplicate: Don't create if one exists for the same user/inbox/meta_key in the time window
      next if Notification.where(
        user: user,
        notification_type: type,
        primary_actor: inbox,
        created_at: dedup_window.ago..Time.current
      ).exists?(['meta ->> ? = ?', dedup_key, dedup_value])

      Notification.create!(
        notification_type: type,
        account: inbox.account,
        user: user,
        primary_actor: inbox,
        meta: meta
      )
    rescue StandardError => e
      Rails.logger.error("[Evolution] Failed to create #{type} notification for user #{user.id}: #{e.message}")
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
