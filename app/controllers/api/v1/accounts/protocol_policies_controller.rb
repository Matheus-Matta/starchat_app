class Api::V1::Accounts::ProtocolPoliciesController < Api::V1::Accounts::BaseController
  before_action :fetch_protocol_policy, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @protocol_policies = Current.account.protocol_policies
  end

  def show
  end

  def create
    @protocol_policy = Current.account.protocol_policies.create!(protocol_policy_params)
    render :show
  end

  def update
    @protocol_policy.update!(protocol_policy_params)
    render :show
  end

  def destroy
    @protocol_policy.destroy!
    head :ok
  end

  private

  def fetch_protocol_policy
    @protocol_policy = Current.account.protocol_policies.find(params[:id])
  end

  def check_authorization
    authorize @protocol_policy || ProtocolPolicy
  end

  def protocol_policy_params
    params.require(:protocol_policy).permit(:name, :prefix, :scope, :seq_padding, :include_store_code, :include_city_code, :active, :welcome_message)
  end
end
