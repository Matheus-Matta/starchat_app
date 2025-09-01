module Starchat::Account::ConversationsResolutionSchedulerJob
  def perform
    super

    resolve_cosmos_::conversations
  end

  private

  def resolve_cosmos_::conversations
    CosmosInbox.all.find_each(batch_size: 100) do |cosmos_::inbox|
      inbox = cosmos_::inbox.inbox

      next if inbox.email?

      Cosmos::InboxPendingConversationsResolutionJob.perform_later(
        inbox
      )
    end
  end
end
