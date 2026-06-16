class Api::V1::Accounts::ConversationFlowsController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation_flow, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @conversation_flows = Current.account.conversation_flows
  end

  def show; end

  def create
    @conversation_flow = Current.account.conversation_flows.create!(conversation_flow_params)
  end

  def update
    @conversation_flow.update!(conversation_flow_params)
  end

  def destroy
    @conversation_flow.destroy!
    head :ok
  end

  private

  def fetch_conversation_flow
    @conversation_flow = Current.account.conversation_flows.find(params[:id])
  end

  def conversation_flow_params
    params.require(:conversation_flow).permit(
      :name, :enabled,
      :auto_resolve_duration, :auto_resolve_message, :auto_resolve_ignore_waiting,
      :no_client_interaction_label, :no_agent_interaction_label,
      :reengagement_message, :reengagement_interval
    )
  end
end
