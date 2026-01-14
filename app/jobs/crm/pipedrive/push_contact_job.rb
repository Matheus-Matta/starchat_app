class Crm::Pipedrive::PushContactJob < ApplicationJob
  queue_as :high

  def perform(contact)
    # Prevent Echo: If this contact was updated by Pipedrive recently, skip push
    if Rails.cache.read("pipedrive_source_#{contact.id}")
      Rails.logger.info "[Pipedrive] PushContactJob SKIPPED for Contact ##{contact.id} (Echo Prevention active)"
      return
    end

    Rails.logger.info "[Pipedrive] PushContactJob RUNNING for Contact ##{contact.id}"
    Crm::Pipedrive::PushContactService.new(contact: contact).perform
  end

end
