class Crm::Pipedrive::Listener < BaseListener
  def contact_created(event)
    contact, account = extract_contact_and_account(event)
    push_to_pipedrive(contact)
  end

  def contact_updated(event)
    contact, account = extract_contact_and_account(event)
    push_to_pipedrive(contact)
  end



  private

  def integration_enabled?(contact)
    hook = contact.account.hooks.find_by(app_id: 'pipedrive')
    hook&.settings.try(:[], 'sync_contacts')
  end

  def push_to_pipedrive(contact)
    return unless integration_enabled?(contact)

    Crm::Pipedrive::PushContactJob.perform_later(contact)
  end
end
