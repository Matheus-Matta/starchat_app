class Crm::Pipedrive::IncomingContactJob < ApplicationJob
  queue_as :high

  def perform(account_id, event_type, data_json)
    account = Account.find_by(id: account_id)
    return unless account
    
    data = JSON.parse(data_json)
    service = Crm::Pipedrive::IncomingContactService.new(account: account)
    
    case event_type
    when 'added.person', 'updated.person'
      service.create_or_update(data)
    end
  end
end
