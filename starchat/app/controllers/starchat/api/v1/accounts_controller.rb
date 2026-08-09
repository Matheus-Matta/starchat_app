class Starchat::Api::V1::AccountsController < Api::BaseController
  before_action :fetch_account
  before_action :validate_token_api_access, if: :authenticate_by_access_token?
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

  private

  def validate_token_api_access
    return if @account.api_and_webhooks_enabled?

    render json: { error: 'API access is not enabled for this account' }, status: :forbidden
  end

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

  # Currency is fixed once a customer exists or creation is already in flight,
  # so a second click can't bill a different currency than setup started with.

  def mark_for_deletion
    reason = 'manual_deletion'

    if @account.mark_for_deletion(reason)
      cancel_cloud_subscriptions_for_deletion

      render json: { message: 'Account marked for deletion' }, status: :ok
    else
      render json: { message: @account.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def unmark_for_deletion
    if @account.unmark_for_deletion
      render json: { message: 'Account unmarked for deletion' }, status: :ok
    else
      render json: { message: @account.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
