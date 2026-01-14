class Crm::Pipedrive::DeleteContactJob < ApplicationJob
  queue_as :high

  def perform(account_id, pipedrive_id)
    account = Account.find_by(id: account_id)
    return unless account

    service = Crm::Pipedrive::DeleteContactService.new(account: account)
    service.perform(pipedrive_id)
  end
end
