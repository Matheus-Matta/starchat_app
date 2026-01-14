class Api::V1::Accounts::Integrations::PipedriveController < Api::V1::Accounts::BaseController
  def customer_context
    result = fetch_service.perform
    render_result(result)
  end

  def show
    head :ok
  end

  def deals
    render json: fetch_service.deals
  end

  def leads
    render json: fetch_service.leads
  end

  def activities
    render json: fetch_service.activities
  end

  def filters
    render json: fetch_service.filters
  end

  def users
    render json: fetch_service.users
  end

  def persons
    render json: fetch_service.persons
  end

  def organizations
    render json: fetch_service.organizations
  end

  def destroy
    hook = Current.account.hooks.find_by(app_id: 'pipedrive')
    hook&.destroy!
    head :ok
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

  def render_result(result)
    if result[:error]
      render json: result, status: :bad_request
    else
      render json: result
    end
  end
end
