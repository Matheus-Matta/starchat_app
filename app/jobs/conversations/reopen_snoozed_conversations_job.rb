class Conversations::ReopenSnoozedConversationsJob < ApplicationJob
  queue_as :low

  def perform
    Conversation.where(status: :snoozed)
                .where(snoozed_until: 3.days.ago..Time.current)
                .find_each(batch_size: 100) do |conversation|
      # Reset last_activity_at so the auto-resolution clock restarts on reopen.
      # Without this, a conversation snoozed to the next day reopens with a stale
      # last_activity_at and is immediately auto-resolved in the same scheduler cycle.
      conversation.update!(status: :open, last_activity_at: Time.current)
    end
  end
end
