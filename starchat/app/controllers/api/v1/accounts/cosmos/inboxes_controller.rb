class Api::V1::Accounts::Cosmos::InboxesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Cosmos::Assistant) }

  before_action :set_assistant
  def index
    @inboxes = @assistant.inboxes
  end

  def create
    inbox = Current.account.inboxes.find(assistant_params[:inbox_id])
    @cosmos_::inbox = @assistant.cosmos_::inboxes.build(inbox: inbox)
    @cosmos_::inbox.save!
  end

  def destroy
    @cosmos_::inbox = @assistant.cosmos_::inboxes.find_by!(inbox_id: permitted_params[:inbox_id])
    @cosmos_::inbox.destroy!
    head :no_content
  end

  private

  def set_assistant
    @assistant = account_assistants.find(permitted_params[:assistant_id])
  end

  def account_assistants
    @account_assistants ||= Current.account.cosmos_::assistants
  end

  def permitted_params
    params.permit(:assistant_id, :id, :account_id, :inbox_id)
  end

  def assistant_params
    params.require(:inbox).permit(:inbox_id)
  end
end
