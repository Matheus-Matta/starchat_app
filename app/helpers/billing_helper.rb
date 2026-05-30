module BillingHelper
  private

  def default_plan?(_account)
    false
  end

  def conversations_this_month(account)
    account.conversations.where('created_at > ?', 30.days.ago).count
  end

  def non_web_inboxes(account)
    account.inboxes.where.not(channel_type: Channel::WebWidget.to_s).count
  end

  def agents(account)
    account.users.count
  end
end
