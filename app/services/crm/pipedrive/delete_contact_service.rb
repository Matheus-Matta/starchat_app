class Crm::Pipedrive::DeleteContactService
  def initialize(account:)
    @account = account
    @hook = @account.hooks.find_by(app_id: 'pipedrive')
  end

  def perform(pipedrive_id)
    return unless @hook&.settings.try(:[], 'sync_contacts')

    client = PipedriveClient.new(base_url: @hook.settings['pipedrive_url'], api_token: @hook.settings['api_token'])
    
    # Delete Person using v1 API
    # DELETE /persons/:id
    client.delete_person(id: pipedrive_id)
  end
end
