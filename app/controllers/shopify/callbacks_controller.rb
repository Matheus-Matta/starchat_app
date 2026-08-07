class Shopify::CallbacksController < ApplicationController
  include Shopify::IntegrationHelper

  def show
    verify_account!

    @response = oauth_client.auth_code.get_token(
      params[:code],
      redirect_uri: '/shopify/callback',
      expiring: '1'
    )

    handle_response
  rescue StandardError => e
    Rails.logger.error("Shopify callback error: #{e.message}")
    redirect_to "#{redirect_uri}?error=true"
  end

  private

  def verify_account!
    @account_id = verify_shopify_token(params[:state])
    raise StandardError, 'Invalid state parameter' if account.blank?
  end

  def handle_response
    now = Time.current
    expires_in = parsed_body['expires_in']
    refresh_token_expires_in = parsed_body['refresh_token_expires_in']

    hook = account.hooks.find_or_initialize_by(app_id: 'shopify')
    hook.access_token = parsed_body['access_token']
    hook.status = 'enabled'
    hook.reference_id = params[:shop]
    hook.settings = hook.settings.merge(
      'scope' => parsed_body['scope'],
      'expires_at' => expires_in ? (now + expires_in.to_i.seconds).utc.iso8601 : nil,
      'refresh_token' => parsed_body['refresh_token'],
      'refresh_token_expires_at' => refresh_token_expires_in ? (now + refresh_token_expires_in.to_i.seconds).utc.iso8601 : nil
    ).compact
    hook.save!

    redirect_to shopify_integration_url
  end

  def parsed_body
    @parsed_body ||= @response.response.parsed
  end

  def oauth_client
    OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: "https://#{params[:shop]}",
        authorize_url: '/admin/oauth/authorize',
        token_url: '/admin/oauth/access_token'
      }
    )
  end

  def account
    @account ||= Account.find(@account_id)
  end

  def account_id
    @account_id ||= params[:state].split('_').first
  end

  def shopify_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/settings/integrations/shopify"
  end

  def redirect_uri
    return shopify_integration_url if account

    ENV.fetch('FRONTEND_URL', nil)
  end
end
