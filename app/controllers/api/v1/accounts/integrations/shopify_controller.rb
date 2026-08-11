class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::Integrations::BaseController
  include Shopify::IntegrationHelper
  before_action :setup_shopify_context, only: [:orders]
  before_action :fetch_hook, except: [:auth]
  before_action :check_token_not_expired!, only: [:orders]
  before_action :check_authorization, only: [:destroy]
  before_action :validate_contact, only: [:orders]

  def auth
    shop_domain = params[:shop_domain]
    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?

    state = generate_shopify_token(Current.account.id)

    auth_url = "https://#{shop_domain}/admin/oauth/authorize?"
    auth_url += URI.encode_www_form(
      client_id: client_id,
      scope: REQUIRED_SCOPES.join(','),
      redirect_uri: redirect_uri,
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def orders
    @orders_retry ||= 0
    render json: { orders: fetch_orders_for_contact }
  rescue ShopifyAPI::Errors::HttpResponseError => e
    if e.code == 401 && @orders_retry.zero? && refresh_access_token!
      @orders_retry += 1
      @shopify_client = nil
      retry
    elsif e.code == 401
      render json: { error: 'Shopify authorization failed. Please reconnect your store.', reconnect_required: true },
             status: :unauthorized
    else
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/shopify/callback"
  end

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'shopify')
  end

  def fetch_orders_for_contact
    return [] if contact.email.blank?

    shopify_client.get(
      path: 'orders.json',
      query: {
        email: contact.email,
        status: 'any',
        fields: 'id,email,created_at,total_price,currency,fulfillment_status,financial_status'
      }
    ).body['orders']&.map do |order|
      order.merge('admin_url' => "https://#{@hook.reference_id}/admin/orders/#{order['id']}")
    end || []
  end

  def setup_shopify_context
    return if client_id.blank? || client_secret.blank?

    ShopifyAPI::Context.setup(
      api_key: client_id,
      api_secret_key: client_secret,
      api_version: '2025-01'.freeze,
      scope: REQUIRED_SCOPES.join(','),
      is_embedded: true,
      is_private: false
    )
  end

  def check_token_not_expired!
    expires_at_str = @hook.settings['expires_at']
    return if expires_at_str.blank?
    return if Time.parse(expires_at_str) > 1.minute.from_now

    return if refresh_access_token!

    render json: { error: 'Shopify token expired. Please reconnect your store.', reconnect_required: true },
           status: :unauthorized
  end

  def refresh_access_token!
    refresh_token = @hook.settings['refresh_token']
    return false if refresh_token.blank?

    rt_expires_at = @hook.settings['refresh_token_expires_at']
    return false if rt_expires_at.present? && Time.parse(rt_expires_at) <= Time.current

    conn = Faraday.new(url: "https://#{@hook.reference_id}")
    response = conn.post('/admin/oauth/access_token') do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.headers['Accept'] = 'application/json'
      req.body = URI.encode_www_form(
        client_id: client_id,
        client_secret: client_secret,
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      )
    end

    return false unless response.status == 200

    body = JSON.parse(response.body)
    new_access_token = body['access_token']
    return false if new_access_token.blank?

    now = Time.current
    expires_in = body['expires_in']
    refresh_token_expires_in = body['refresh_token_expires_in']

    @hook.update!(
      access_token: new_access_token,
      settings: @hook.settings.merge(
        'expires_at' => expires_in ? (now + expires_in.to_i.seconds).utc.iso8601 : nil,
        'refresh_token' => body['refresh_token'] || refresh_token,
        'refresh_token_expires_at' => refresh_token_expires_in ? (now + refresh_token_expires_in.to_i.seconds).utc.iso8601 : nil
      ).compact
    )
    true
  rescue StandardError => e
    Rails.logger.error("Shopify token refresh failed: #{e.message}")
    false
  end

  def shopify_session
    expires = @hook.settings['expires_at']&.then { |t| Time.parse(t) }
    ShopifyAPI::Auth::Session.new(shop: @hook.reference_id, access_token: @hook.access_token, expires: expires)
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Rest::Admin.new(session: shopify_session)
  end

  def validate_contact
    return if contact.present? && contact.email.present?

    render json: { error: 'Contact email is required to search Shopify orders' },
           status: :unprocessable_entity
  end
end
