# app/controllers/api/v1/accounts/integrations/typebot_controller.rb
class Api::V1::Accounts::Integrations::TypebotController < Api::V1::Accounts::BaseController
  before_action :fetch_hook, only: [:update, :destroy, :send_message]

  def create
    @hook = Integrations::Typebot::HookBuilder.new(
      account: Current.account,
      inbox_id: params.require(:inbox_id),
      share_url: permitted_params[:share_url],
      api_token: permitted_params[:api_token],
      session_ttl_seconds: permitted_params[:session_ttl_seconds]
    ).perform
  rescue Integrations::Typebot::HookBuilder::BuildError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    @hook = Integrations::Typebot::SettingsUpdater.new(
      hook: @hook,
      share_url: permitted_params[:share_url],
      api_token: permitted_params[:api_token],
      session_ttl_seconds: permitted_params[:session_ttl_seconds]
    ).perform
  rescue Integrations::Typebot::SettingsUpdater::UpdateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook&.destroy!
    head :ok
  end

  def send_message
    conversation = Conversation.find(params.require(:conversation_id))
    msg = conversation.messages.create!(
      message_type: :incoming,
      content: params.require(:message),
      private: false
    )
    @hook.process_event(name: 'message_created', data: { message_id: msg.id })
    render json: { ok: true }
  end

  skip_before_action :authenticate_user!, only: [:webhook]
  def webhook
    conversation = Conversation.find_by(id: params[:conversation_id])
    return head :not_found unless conversation

    text = params[:text].to_s
    return head :ok if text.blank?

    conversation.messages.create!(
      message_type: :outgoing,
      content: text,
      private: false
    )
    head :ok
  end

  private

  def fetch_hook
    @hook = Integrations::Hook.where(account: Current.account).find_by(app_id: 'typebot')
  end

  def permitted_params
    params.permit(:share_url, :api_token, :session_ttl_seconds, :inbox_id)
  end
end
