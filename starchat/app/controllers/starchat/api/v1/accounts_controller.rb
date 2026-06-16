class Starchat::Api::V1::AccountsController < Api::BaseController
  include BillingHelper
  before_action :fetch_account
  before_action :check_authorization

  def subscription
    head :no_content
  end

  def limits
    limits = if default_plan?(@account)
               {
                 'conversation' => {
                   'allowed' => 500,
                   'consumed' => conversations_this_month(@account)
                 },
                 'non_web_inboxes' => {
                   'allowed' => 0,
                   'consumed' => non_web_inboxes(@account)
                 },
                 'agents' => {
                   'allowed' => 2,
                   'consumed' => agents(@account)
                 }
               }
             else
               default_limits
             end

    # include id in response to ensure that the store can be updated on the frontend
    render json: { id: @account.id, limits: limits }, status: :ok
  end

  def checkout
    render_invalid_billing_details
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

  def topup_checkout
    return render json: { error: I18n.t('errors.topup.credits_required') }, status: :unprocessable_entity if params[:credits].blank?

    service = Starchat::Billing::TopupCheckoutService.new(account: @account)
    result = service.create_checkout_session(credits: params[:credits].to_i)

    @account.reload
    render json: result.merge(
      id: @account.id,
      limits: @account.limits,
      custom_attributes: @account.custom_attributes
    )
  rescue Starchat::Billing::TopupCheckoutService::Error, Stripe::StripeError => e
    render_could_not_create_error(e.message)
  end

  private


  def default_limits
    {
      'conversation' => {},
      'non_web_inboxes' => {},
      'agents' => {
        'allowed' => @account.usage_limits[:agents],
        'consumed' => agents(@account)
      },
      'cosmos' => @account.usage_limits[:cosmos]
    }
  end

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def render_invalid_billing_details
    render_could_not_create_error('Billing details are not available')
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
