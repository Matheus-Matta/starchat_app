module Starchat::Account::ConversationsResolutionSchedulerJob
  def perform
    super

    resolve_cosmos_conversations
  end

  private

  def resolve_cosmos_conversations
    CosmosInbox.all.find_each(batch_size: 100) do |cosmos_inbox|
      inbox = cosmos_inbox.inbox

      next if inbox.email?

      Cosmos::InboxPendingConversationsResolutionJob.perform_later(
        inbox
      )
    end
  end
end
