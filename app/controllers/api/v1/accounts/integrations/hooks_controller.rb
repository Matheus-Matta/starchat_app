class Api::V1::Accounts::Integrations::HooksController < Api::V1::Accounts::BaseController
  before_action :fetch_hook, except: [:create]
  before_action :check_authorization

  def create
    p = permitted_params
    ensure_pipedrive_url(p)
    @hook = Current.account.hooks.create!(p)
    handle_pipedrive_updates
  end

  def update
    p = permitted_params.slice(:status, :settings)
    ensure_pipedrive_url(p)
    @hook.update!(p)
    handle_pipedrive_updates
  end
  
  def process_event
    response = @hook.process_event(params[:event])

    # for cases like an invalid event, or when conversation does not have enough messages
    # for a label suggestion, the response is nil
    if response.nil?
      render json: { message: nil }
    elsif response[:error]
      render json: { error: response[:error] }, status: :unprocessable_entity
    else
      render json: { message: response[:message] }
    end
  end

  def destroy
    @hook.destroy!
    head :ok
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find(params[:id])
  end

  def check_authorization
    authorize(:hook)
  end

  def permitted_params
    p = params.require(:hook).permit(:app_id, :inbox_id, :status)
    p[:settings] = params[:hook][:settings].permit! if params[:hook][:settings]
    p
  end

  def ensure_pipedrive_url(params)
    return unless params[:settings] && params[:settings]['company_domain'].present?

    unless params[:settings]['pipedrive_url'].present?
      params[:settings]['pipedrive_url'] = "https://#{params[:settings]['company_domain']}.pipedrive.com"
    end
  end

  def handle_pipedrive_updates
    return unless @hook.app_id == 'pipedrive'

    if @hook.settings['sync_contacts']
      Crm::Pipedrive::SyncContactsJob.perform_later(@hook.account_id)
    end
    
    manage_pipedrive_webhook
  end

  def manage_pipedrive_webhook
    settings = @hook.settings || {}
    return unless settings['pipedrive_url'].present? && settings['api_token'].present?

    client = PipedriveClient.new(base_url: settings['pipedrive_url'], api_token: settings['api_token'])

    if settings['sync_contacts']
      unless settings['webhook_id']
        settings['webhook_token'] ||= SecureRandom.hex(16)
        base_url = ENV['FRONTEND_URL'].to_s.gsub(/\/$/, '')
        url = "#{base_url}/webhook/pipedrive/#{@hook.account_id}/#{settings['webhook_token']}"

        # Clean/Reuse existing webhooks
        begin
          existing = client.webhooks
          if existing && existing['success'] && existing['data'].present?
             duplicates = existing['data'].select { |wh| wh['subscription_url'].to_s.include?(base_url) }
             duplicates.each do |dup|
               if dup['subscription_url'] == url
                 settings['webhook_id'] = dup['id']
                 @hook.update_columns(settings: settings)
                 return
               else
                 client.delete_webhook(id: dup['id'])
               end
             end
          end
        rescue => e
           Rails.logger.error "[Pipedrive] Error checking existing webhooks: #{e.message}"
        end

        res = client.create_webhook(
          subscription_url: url,
          event_action: '*',
          event_object: 'person'
        )
        if res && res['success']
          settings['webhook_id'] = res['data']['id']
          @hook.update_columns(settings: settings)
        end
      end
    else
      if settings['webhook_id']
        client.delete_webhook(id: settings['webhook_id'])
        settings.delete('webhook_id')
        @hook.update_columns(settings: settings)
      end
    end
  rescue => e
    Rails.logger.error "Error managing Pipedrive webhook: #{e.message}"
  end
end
