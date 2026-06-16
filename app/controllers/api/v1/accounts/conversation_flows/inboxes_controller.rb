class Api::V1::Accounts::ConversationFlows::InboxesController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation_flow
  before_action -> { check_authorization(ConversationFlow) }

  def index
    @inboxes = @conversation_flow.inboxes
  end

  def create
    inbox = Current.account.inboxes.find(params[:inbox_id])
    existing = InboxConversationFlow.find_by(inbox: inbox)
    existing.destroy! if existing
    InboxConversationFlow.create!(inbox: inbox, conversation_flow: @conversation_flow)
    head :ok
  end

  def destroy
    inbox = Current.account.inboxes.find(params[:id])
    InboxConversationFlow.find_by!(inbox: inbox, conversation_flow: @conversation_flow).destroy!
    head :ok
  end

  private

  def fetch_conversation_flow
    @conversation_flow = Current.account.conversation_flows.find(params[:conversation_flow_id])
  end
end
