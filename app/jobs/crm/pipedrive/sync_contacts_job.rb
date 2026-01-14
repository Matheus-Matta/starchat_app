class Crm::Pipedrive::SyncContactsJob < ApplicationJob
  queue_as :low

  def perform(account_id, start = 0)
    account = Account.find_by(id: account_id)
    return unless account

    service = Crm::Pipedrive::SyncContactsService.new(account: account, start: start)
    result = service.perform
    
    if result && result[:has_more]
      self.class.perform_later(account_id, result[:next_start])
    end
  end
end
