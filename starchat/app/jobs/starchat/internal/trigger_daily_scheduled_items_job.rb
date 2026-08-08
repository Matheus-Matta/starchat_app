module Starchat::Internal::TriggerDailyScheduledItemsJob
  def perform
    super

    # Every account is on the same footing here, so document sync runs once for
    # all of them rather than on a per-plan cadence.
    Cosmos::Documents::ScheduleSyncsJob.perform_later
  end
end
