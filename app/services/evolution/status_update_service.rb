# app/services/evolution/status_update_service.rb
# frozen_string_literal: true

class Evolution::StatusUpdateService
  def initialize(inbox:, raw_updates:)
    @inbox = inbox
    @raw   = raw_updates.with_indifferent_access
  end

  def perform
    statuses = Array(@raw[:statuses]) + Array(@raw[:statusUpdates])
    statuses.each do |st|
      h = st.with_indifferent_access
      source_id = h[:id] || h[:messageId] || h.dig(:key, :id)
      next if source_id.blank?

      msg = Message.find_by(inbox_id: @inbox.id, source_id: source_id)
      next unless msg

      case normalize_status(h[:status])
      when 'delivered' then msg.update!(status: :delivered) rescue nil
      when 'read'      then msg.update!(status: :read)      rescue nil
      end
    end
  end

  private

  def normalize_status(s)
    up = s.to_s.upcase
    return 'delivered' if %w[DELIVERY_ACK DELIVERED SERVER_ACK].include?(up)
    return 'read'      if %w[READ SEEN].include?(up)
    s.to_s.downcase
  end
end
