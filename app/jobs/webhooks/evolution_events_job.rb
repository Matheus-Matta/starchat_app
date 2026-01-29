# app/jobs/webhooks/evolution_events_job.rb
# frozen_string_literal: true

class Webhooks::EvolutionEventsJob < ApplicationJob
  queue_as :evolution

  def perform(inbox_id:, event:, data:)
    @inbox = Inbox.find_by(id: inbox_id)
    return unless @inbox&.channel.is_a?(Channel::Evolution)

    # Set URL options for ActiveStorage URL generation in background jobs
    base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000').to_s.chomp('/')
    ActiveStorage::Current.url_options = { host: base_url }

    evt  = event.to_s.tr('.', '_').downcase
    rows = Array.wrap(data).compact
    rows = rows.reject { |r| r.respond_to?(:empty?) && r.empty? }

    Rails.logger.debug { "\n\n[EVOLUTION DATA ROWS EVENT = #{evt}]" }

    case evt
    when 'messages_upsert'
      rows.each do |raw|
        safely('incoming message') do
          next if raw.blank?

          Evolution::IncomingMessageService.new(
            inbox: @inbox,
            processed: raw
          ).perform
        end
      end

    when 'messages_update'
      rows.each do |row|
        safely('status update') do
          next if row.blank?

          Evolution::MessageStatusService.new(
            inbox: @inbox,
            params: row
          ).perform
        end
      end

    when 'contacts_update', 'contacts_upsert'
      safely('contact sync') do
        Evolution::ContactSyncService.new(
          inbox: @inbox,
          list: rows
        ).perform
      end


    when 'call'
      rows.each do |call_event|
        safely('call event') do
          next if call_event.blank?

          Evolution::CallEventJob.perform_later(@inbox.id, call_event)
        end
      end

    else
      Rails.logger.debug { "[Evolution] unknown event=#{evt}" }
    end
  end

  private

  def safely(what)
    yield
  rescue StandardError => e
    Rails.logger.warn "[Evolution] #{what} failed (Inbox##{@inbox&.id}): #{e.class} #{e.message}"
  end
end
