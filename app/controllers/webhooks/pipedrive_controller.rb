class Webhooks::PipedriveController < ActionController::API
  def process_payload
    account_id = params[:account_id]
    return head :bad_request unless account_id

    @account = Account.find_by(id: account_id)
    return head :not_found unless @account

    @hook = @account.hooks.find_by(app_id: 'pipedrive')
    # Use head :ok to acknowledge receipt even if we don't process
    return head :ok unless @hook&.settings.try(:[], 'sync_contacts')

    # Security check: verify token
    incoming_token = params[:token]
    stored_token = @hook.settings['webhook_token']

    if stored_token.present? && incoming_token != stored_token
      return head :unauthorized
    end
    
    # Reliance on secret URL with account_id AND token
    
    # Parse event from meta
    meta = params[:meta] || {}
    action = meta[:action]
    entity = meta[:entity]
    
    # Map 'change' to 'updated' as observed in logs
    normalized_action = (action == 'change') ? 'updated' : action
    event = "#{normalized_action}.#{entity}"

    # Extract data: 'data' is standard, 'current' legacy. 'previous' for context/deletes.
    data = params[:data] || params[:current] || params[:previous]

    if data
      Crm::Pipedrive::IncomingContactJob.perform_later(@account.id, event, data.to_json)
    end

    head :ok
  end
end
