module Starchat::SuperAdmin::AppConfigsController
  private

  def allowed_configs
    
    case @config
    when 'custom_branding'
      @allowed_configs = custom_branding_options
    when 'internal'
      @allowed_configs = internal_config_options
    when 'captain'
      @allowed_configs = captain_config_options
    when 'saml'
      @allowed_configs = saml_config_options
    else
      super
    end
  end

  def custom_branding_options
    %w[
      LOGO_THUMBNAIL
      LOGO
      LOGO_DARK
      BRAND_NAME
      INSTALLATION_NAME
      BRAND_URL
      WIDGET_BRAND_URL
      TERMS_URL
      PRIVACY_URL
      DISPLAY_MANIFEST
    ]
  end

  def internal_config_options
    %w[CHATWOOT_INBOX_TOKEN CHATWOOT_INBOX_HMAC_KEY ANALYTICS_TOKEN CLEARBIT_API_KEY DASHBOARD_SCRIPTS INACTIVE_WHATSAPP_NUMBERS BLOCKED_EMAIL_DOMAINS
       SKIP_INCOMING_BCC_PROCESSING COSMOS_CLOUD_PLAN_LIMITS ACCOUNT_SECURITY_NOTIFICATION_WEBHOOK_URL CHATWOOT_INSTANCE_ADMIN_EMAIL
       OG_IMAGE_CDN_URL OG_IMAGE_CLIENT_REF CLOUDFLARE_API_KEY CLOUDFLARE_ZONE_ID]
  end

  def cosmos_config_options
    %w[
      COSMOS_OPEN_AI_API_KEY
      COSMOS_OPEN_AI_MODEL
      COSMOS_OPEN_AI_ENDPOINT
      COSMOS_EMBEDDING_MODEL
      COSMOS_FIRECRAWL_API_KEY
    ]
  end

  def saml_config_options
    %w[ENABLE_SAML_SSO_LOGIN]
  end
end
