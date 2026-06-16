class Internal::AccountAnalysisJob < ApplicationJob
  queue_as :low

  def perform(account)
Internal::AccountAnalysis::ThreatAnalyserService.new(account).perform
  end
end
