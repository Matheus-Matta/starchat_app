class Starchat::CreateStripeCustomerJob < ApplicationJob
  queue_as :default

  def perform(account)
  end
end
