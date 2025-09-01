# app/jobs/webhooks/evolution_events_job.rb
# frozen_string_literal: true
class Webhooks::EvolutionEventsJob < ApplicationJob
  queue_as :low

  def perform(inbox_id:, event:, data:)
    @inbox = Inbox.find_by(id: inbox_id)
    return unless @inbox&.channel.is_a?(Channel::Evolution)

    evt = event.to_s.tr('.', '_').downcase
    rows = Array.wrap(data)

    case evt
    when 'messages_upsert'
      rows.each do |msg|
        safely('incoming message') do
          Evolution::IncomingMessageService.new(inbox: @inbox, raw_message: msg).perform
        end
      end

    when 'messages_update'
      statuses = rows.map do |row|
        h = row.with_indifferent_access
        {
          id:     h[:keyId] || h[:messageId] || h.dig(:key, :id) || h[:id],
          status: map_status(h[:status])
        }.compact
      end
      safely('status updates') do
        Evolution::StatusUpdateService.new(
          inbox: @inbox,
          raw_updates: { statuses: statuses }
        ).perform
      end

    when 'contacts_update', 'contacts_upsert'
      safely('contact sync') do
        Evolution::ContactSyncService.new(inbox: @inbox, list: rows).perform
      end

    when 'chats_update'
      safely('chats warmup') do
        Evolution::WarmupChatService.new(inbox: @inbox, list: rows).perform
      end

    else
      Rails.logger.debug { "[Evolution] unknown event=#{evt}" }
    end
  end

  private

  def map_status(s)
    case s.to_s.upcase
    when 'DELIVERY_ACK', 'DELIVERED' then 'delivered'
    when 'READ', 'SEEN'              then 'read'
    else s.to_s.downcase
    end
  end

  def safely(what)
    yield
  rescue => e
    Rails.logger.warn "[Evolution] #{what} failed (Inbox##{@inbox&.id}): #{e.class} #{e.message}"
  end
end
