class Account::ConversationsReengagementSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ConversationFlow.with_reengagement.find_each(batch_size: 100) do |flow|
      Conversations::ReengagementJob.perform_later(flow: flow)
    end
  end
end
Account::ConversationsReengagementSchedulerJob.prepend_mod_with('Account::ConversationsReengagementSchedulerJob')
