# frozen_string_literal: true

class Starchat::SyncDefaultAccountFeaturesService
  DEFAULT_ENABLED_FEATURES = YAML.safe_load(
    File.read(Rails.root.join('config/features.yml'))
  ).select { |f| f['enabled'] }.pluck('name').freeze

  def perform
    updated = 0
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| updated += 1 if sync_account(account) }
    end
    Rails.logger.info "[SyncDefaultAccountFeaturesService] #{updated} account(s) updated."
    updated
  end

  private

  def sync_account(account)
    missing = DEFAULT_ENABLED_FEATURES.reject { |f| account.feature_enabled?(f) }
    missing << 'saml' if saml_configured?(account) && !account.feature_enabled?('saml')
    return false if missing.empty?

    account.enable_features(*missing)
    account.save!
    true
  rescue StandardError => e
    Rails.logger.error "[SyncDefaultAccountFeaturesService] account #{account.id}: #{e.message}"
    false
  end

  def saml_configured?(account)
    AccountSamlSettings.where(account_id: account.id).exists?
  rescue StandardError
    false
  end
end
