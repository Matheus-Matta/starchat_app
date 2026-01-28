class PresenceBroadcastJob < ApplicationJob
  queue_as :low

  def perform(account_id)
    account = Account.find(account_id)
    data = {
      account_id: account.id,
      users: OnlineStatusTracker.get_available_users(account.id),
      contacts: OnlineStatusTracker.get_available_contacts(account.id)
    }

    ActionCable.server.broadcast("account_#{account.id}", { event: 'presence.update', data: data })
  end
end
