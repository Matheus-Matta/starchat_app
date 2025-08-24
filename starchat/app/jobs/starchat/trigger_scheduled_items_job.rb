module Starchat::TriggerScheduledItemsJob
  def perform
    super
    Sla::TriggerSlasForAccountsJob.perform_later
  end
end
