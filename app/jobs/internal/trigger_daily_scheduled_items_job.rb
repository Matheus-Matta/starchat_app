class Internal::TriggerDailyScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Schedule daily deferred jobs here so each installation can spread load
    # across the day without changing its slot on deploys or restarts.
  end
end

Internal::TriggerDailyScheduledItemsJob.prepend_mod_with('Internal::TriggerDailyScheduledItemsJob')
