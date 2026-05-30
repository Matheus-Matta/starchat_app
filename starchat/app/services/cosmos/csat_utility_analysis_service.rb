# frozen_string_literal: true

class Cosmos::CsatUtilityAnalysisService
  def initialize(account:, message:, button_text: nil, language: 'en', baseline: nil)
    @account = account
    @message = message
    @button_text = button_text
    @language = language
    @baseline = baseline
  end

  def perform
    { error: 'Not implemented' }
  end
end
