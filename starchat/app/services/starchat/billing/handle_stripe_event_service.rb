class Starchat::Billing::HandleStripeEventService
  CLOUD_PLANS_CONFIG = 'CHATWOOT_CLOUD_PLANS'.freeze

  STARTUP_PLAN_FEATURES = %w[
    inbound_emails
    help_center
    campaigns
    team_management
    channel_twitter
    channel_facebook
    channel_email
    channel_instagram
    cosmos_::integration
  ].freeze


  BUSINESS_PLAN_FEATURES = %w[sla custom_roles].freeze


  ENTERPRISE_PLAN_FEATURES = %w[audit_logs disable_branding].freeze

  def perform(event:)
    @event = event
    Rails.logger.debug { "Stripe event handling removido" }
  end

  private

  def update_plan_features
    if default_plan?
      disable_all_premium_features
    else
      enable_features_for_current_plan
    end

    enable_account_manually_managed_features

    account.save!
  end

  def disable_all_premium_features
    account.disable_features(*STARTUP_PLAN_FEATURES)
    account.disable_features(*BUSINESS_PLAN_FEATURES)
    account.disable_features(*ENTERPRISE_PLAN_FEATURES)
  end

  def enable_features_for_current_plan
    disable_all_premium_features
    enable_plan_specific_features
  end

  def enable_plan_specific_features
    plan_name = account.custom_attributes['plan_name']
    return if plan_name.blank?
    case plan_name
    when 'Startups'
      account.enable_features(*STARTUP_PLAN_FEATURES)
    when 'Business'
      # Business plan gets Startups features + Business features
      account.enable_features(*STARTUP_PLAN_FEATURES)
      account.enable_features(*BUSINESS_PLAN_FEATURES)
    when 'Enterprise'
      # Enterprise plan gets all features
      account.enable_features(*STARTUP_PLAN_FEATURES)
      account.enable_features(*BUSINESS_PLAN_FEATURES)
      account.enable_features(*ENTERPRISE_PLAN_FEATURES)
    end
  end

  def account
    # Mantido: busca da conta pelo stripe_customer_id, pode ser ajustado conforme necessidade
    @account ||= Account.where("custom_attributes->>'stripe_customer_id' = ?", nil).first
  end

  def enable_account_manually_managed_features
    # Get manually managed features from internal attributes using the service
    service = Internal::Accounts::InternalAttributesService.new(account)
    features = service.manually_managed_features

    # Enable each feature
    account.enable_features(*features) if features.present?
  end
end
