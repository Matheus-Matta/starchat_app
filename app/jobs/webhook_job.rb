class WebhookJob < ApplicationJob
  queue_as :medium
  sidekiq_options retry: 3

  #  There are 3 types of webhooks, account, inbox and agent_bot
  def perform(url, payload, webhook_type = :account_webhook)
    Webhooks::Trigger.execute(url, payload, webhook_type)
  end
end
