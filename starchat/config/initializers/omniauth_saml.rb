# Starchat Edition SAML SSO Provider
# This initializer adds SAML authentication support for Starchat customers

# SAML setup proc for multi-tenant configuration
SAML_SETUP_PROC = proc do |env|
  strategy = env['omniauth.strategy']
  # In OmniAuth test mode, strategy may be nil — skip configuration
  next if strategy.nil?

  request = ActionDispatch::Request.new(env)

  # Extract account_id from various sources
  account_id = request.params['account_id'] ||
               request.session[:saml_account_id] ||
               env['omniauth.params']&.dig('account_id')
  relay_state = request.params['RelayState'] || ''

  if account_id
    # Store in session and omniauth params for callback
    request.session[:saml_account_id] = account_id
    request.session[:saml_relay_state] = relay_state
    env['omniauth.params'] ||= {}
    env['omniauth.params']['account_id'] = account_id
    env['omniauth.params']['RelayState'] = relay_state

    # Find SAML settings for this account
    settings = AccountSamlSettings.find_by(account_id: account_id)

    if settings
      strategy.options[:idp_sso_service_url_runtime_params] = { RelayState: :RelayState }
      strategy.options[:assertion_consumer_service_url] = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/omniauth/saml/callback?account_id=#{account_id}"
      strategy.options[:sp_entity_id] = settings.sp_entity_id
      strategy.options[:idp_entity_id] = settings.idp_entity_id
      strategy.options[:idp_sso_service_url] = settings.sso_url
      strategy.options[:idp_cert] = settings.certificate
      strategy.options[:name_identifier_format] = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
    else
      strategy.options[:idp_cert] = 'DUMMY'
    end
  else
    strategy.options[:idp_cert] = 'DUMMY'
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  # path_prefix must match the DeviseTokenAuth omniauth prefix (/omniauth)
  # so OmniAuth intercepts POST /omniauth/saml/callback (real SAML assertion)
  # and in test mode GET /omniauth/saml/callback (mock)
  provider :saml, path_prefix: '/omniauth', setup: SAML_SETUP_PROC
end
