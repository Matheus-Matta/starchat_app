module Starchat::Api::V1::AccountsSettings
  def create
    super

    record_marketing_attribution
  end

  private

  # Only a fresh signup carries marketing attribution. An authenticated user adding a
  # second workspace was already attributed on their first account, so re-recording the
  # cookies there would credit the new account to a campaign it never came from.
  #
  # The service itself is a no-op off cloud or without attribution cookies, so this only
  # has to answer the "is this a signup?" question.
  def record_marketing_attribution
    return if current_user.present?
    return if @account.blank?

    Internal::Accounts::MarketingAttributionService.new(account: @account, cookies: cookies).perform
  end
end
