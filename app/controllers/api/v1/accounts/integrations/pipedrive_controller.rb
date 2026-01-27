class Api::V1::Accounts::Integrations::PipedriveController < Api::V1::Accounts::BaseController
  def customer_context
    result = fetch_service.perform
    render_result(result)
  end

  def show
    head :ok
  end

  def deals
    render_result(fetch_service.deals)
  end

  def leads
    render_result(fetch_service.leads)
  end

  def activities
    render_result(fetch_service.activities)
  end

  def filters
    render_result(fetch_service.filters)
  end

  def users
    render_result(fetch_service.users)
  end

  def persons
    render_result(fetch_service.persons)
  end

  def organizations
    render_result(fetch_service.organizations)
  end

  def lead_labels
    render_result(fetch_service.lead_labels)
  end

  def search_products
    render_result(fetch_service.search_products(params[:term]))
  end

  def destroy
    hook = Current.account.hooks.find_by(app_id: 'pipedrive')
    hook&.destroy!
    head :ok
  end

  def create_deal
    render_result(create_service.perform_deal)
  end

  def create_lead
    render_result(create_service.perform_lead)
  end

  def create_activity
    render_result(create_service.perform_activity)
  end

  def update_deal
    render_result(manage_service.update_deal)
  end

  def delete_deal
    render_result(manage_service.delete_deal)
  end

  def update_lead
    render_result(manage_service.update_lead)
  end

  def delete_lead
    render_result(manage_service.delete_lead)
  end

  def update_activity
    render_result(manage_service.update_activity)
  end

  def delete_activity
    render_result(manage_service.delete_activity)
  end

  private

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_service
    if params[:contact_id].present?
      @service ||= Crm::Pipedrive::FetchCustomerContextService.new(contact: contact)
    else
      @service ||= Crm::Pipedrive::BrowseResourcesService.new(account: Current.account, params: params)
    end
  end

  def create_service
    @create_service ||= Crm::Pipedrive::CreateResourceService.new(account: Current.account, params: params)
  end

  def manage_service
    @manage_service ||= Crm::Pipedrive::ManageResourceService.new(account: Current.account, params: params)
  end

  def render_result(result)
    if result.nil? || result[:error]
      render json: result || { error: 'Unknown Error' }, status: :bad_request
    else
      render json: result
    end
  end
end
