class Starchat::Api::V1::AccountsController < Api::BaseController
  before_action :fetch_account
  before_action :check_authorization

  def limits
    # include id in response to ensure that the store can be updated on the frontend
    render json: { id: @account.id, limits: default_limits }, status: :ok
  end

  def toggle_deletion
    action_type = params[:action_type]

    case action_type
    when 'delete'
      @account.mark_for_deletion
      render json: { id: @account.id, custom_attributes: @account.custom_attributes }, status: :ok
    when 'undelete'
      @account.unmark_for_deletion
      render json: { id: @account.id, custom_attributes: @account.custom_attributes }, status: :ok
    else
      render json: { error: 'Invalid action_type. Must be either "delete" or "undelete"' }, status: :unprocessable_entity
    end
  end

  private

  def default_limits
    {
      'conversation' => {},
      'non_web_inboxes' => {},
      'agents' => {
        'allowed' => @account.usage_limits[:agents],
        'consumed' => @account.users.count
      },
      'cosmos' => @account.usage_limits[:cosmos]
    }
  end

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
