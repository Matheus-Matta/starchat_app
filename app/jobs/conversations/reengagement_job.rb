class Conversations::ReengagementJob < ApplicationJob
  queue_as :low

  def perform(flow:)
    return unless flow.reengagement_active?

    flow.inboxes.find_each(batch_size: 50) do |inbox|
      scope = inbox.conversations
                   .needs_reengagement(flow.reengagement_interval)
                   .not_yet_resolvable(flow.auto_resolve_duration)

      scope.find_in_batches(batch_size: 100) do |batch|
        batch.each do |conversation|
          send_reengagement(conversation, flow.reengagement_message)
        rescue StandardError => e
          Rails.logger.error "ReengagementJob conv=#{conversation.id}: #{e.message}"
        end
      end
    end
  end

  private

  def send_reengagement(conversation, message)
    conversation.reload
    return if conversation.waiting_since.present? || !conversation.open?

    original_activity_at = conversation.last_activity_at
    ::MessageTemplates::Template::Reengagement.new(conversation: conversation, message: message).perform
    conversation.update_columns(last_activity_at: original_activity_at, last_reengagement_at: Time.current)
  end
end
