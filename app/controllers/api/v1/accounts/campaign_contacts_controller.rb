class Api::V1::Accounts::CampaignContactsController < Api::V1::Accounts::BaseController
  before_action :campaign

  def index
    authorize @campaign, :show?

    @campaign_contacts = @campaign.campaign_contacts
                                  .includes(:contact)
                                  .order(created_at: :asc)
                                  .page(params[:page])
                                  .per(25)
  end

  private

  def campaign
    @campaign ||= Current.account.campaigns.find_by!(display_id: params[:campaign_id])
  end
end
