class Account::ConversationsResolutionSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    each_account_with_resolution_policy do |account|
      Conversations::ResolutionJob.perform_later(account: account)
    end
  end

  private

  def each_account_with_resolution_policy(&block)
    account_ids = (
      Account.with_auto_resolve.pluck(:id) +
      Inbox.with_inbox_auto_resolve.pluck(:account_id) +
      flow_account_ids
    ).uniq

    Account.where(id: account_ids).find_each(batch_size: 100, &block)
  end

  def flow_account_ids
    InboxConversationFlow
      .joins(:conversation_flow, :inbox)
      .merge(ConversationFlow.with_auto_resolve)
      .pluck('inboxes.account_id')
  end
end
Account::ConversationsResolutionSchedulerJob.prepend_mod_with('Account::ConversationsResolutionSchedulerJob')
