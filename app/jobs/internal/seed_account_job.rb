class Internal::SeedAccountJob < ApplicationJob
  queue_as :low

  def perform(account)
    raise 'Account Seeding is not allowed in production.' if Rails.env.production?

    Seeders::AccountSeeder.new(account: account).perform!
  end
end
