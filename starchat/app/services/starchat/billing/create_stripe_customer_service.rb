class Starchat::Billing::CreateStripeCustomerService
  pattr_initialize [:account!]

  DEFAULT_QUANTITY = 2

  def perform
    account.update!(
      custom_attributes: {
        plan_name: default_plan['name'],
      }
    )
  end

  private


  def default_quantity
    default_plan['default_quantity'] || DEFAULT_QUANTITY
  end

  def billing_email
    account.administrators.first.email
  end

  def default_plan
    installation_config = InstallationConfig.find_by(name: 'CHATWOOT_CLOUD_PLANS')
    @default_plan ||= installation_config.value.first
  end

end
