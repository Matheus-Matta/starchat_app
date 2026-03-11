class Account::ConversationsResolutionSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # 1. Contas com auto_resolve global (comportamento original)
    Account.with_auto_resolve.find_each(batch_size: 100) do |account|
      Conversations::ResolutionJob.perform_later(account: account)
    end

    # 2. Inboxes com politica propria de auto_resolve (prioridade inbox > conta)
    Inbox.with_inbox_auto_resolve.includes(:account).find_each(batch_size: 100) do |inbox|
      Conversations::ResolutionJob.perform_later(account: inbox.account, inbox: inbox)
    end
  end
end
Account::ConversationsResolutionSchedulerJob.prepend_mod_with('Account::ConversationsResolutionSchedulerJob')
