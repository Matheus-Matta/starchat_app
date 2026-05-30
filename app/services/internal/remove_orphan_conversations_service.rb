class Internal::RemoveOrphanConversationsService
  def initialize(account: nil, days: 1)
    @account = account
    @days = days
  end

  def perform
    return 0 if production_cleanup_disabled?

    orphan_conversations = build_orphan_conversations_query
    total_deleted = 0

    Rails.logger.info '[RemoveOrphanConversationsService] Starting removal of orphan conversations'

    orphan_conversations.find_in_batches(batch_size: 1000) do |batch|
      conversation_ids = batch.map(&:id)
      Conversation.where(id: conversation_ids).destroy_all
      total_deleted += batch.size
      Rails.logger.info "[RemoveOrphanConversationsService] Deleted #{batch.size} orphan conversations (#{total_deleted} total)"
    end

    Rails.logger.info "[RemoveOrphanConversationsService] Completed. Total deleted: #{total_deleted}"
    total_deleted
  end

  private

  def production_cleanup_disabled?
    return false unless Rails.env.production?
    return false if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_ORPHAN_CONVERSATION_CLEANUP', false))

    Rails.logger.warn '[RemoveOrphanConversationsService] Skipping orphan conversation cleanup in production.'
    true
  end

  def build_orphan_conversations_query
    base = @account ? @account.conversations : Conversation.all
    base = base.where('conversations.last_activity_at > ?', @days.days.ago)
    base = base.left_outer_joins(:contact, :inbox)

    # Find conversations whose associated contact or inbox record is missing
    base.where(contacts: { id: nil }).or(base.where(inboxes: { id: nil }))
  end
end
