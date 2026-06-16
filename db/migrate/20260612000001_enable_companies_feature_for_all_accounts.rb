class EnableCompaniesFeatureForAllAccounts < ActiveRecord::Migration[7.1]
  def up
    # Update ACCOUNT_LEVEL_FEATURE_DEFAULTS so new accounts get companies enabled
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if config&.value.present?
      features = config.value.map do |f|
        if f['name'] == 'companies'
          f.merge('enabled' => true, 'premium' => false, 'chatwoot_internal' => false)
        else
          f
        end
      end
      config.value = features
      config.save!
    end

    # Enable companies for all existing accounts
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each do |account|
        next if account.feature_enabled?('companies')

        account.enable_features!('companies')
      rescue StandardError => e
        Rails.logger.error "EnableCompaniesFeature: account #{account.id} - #{e.message}"
      end
    end

    GlobalConfig.clear_cache
  end
end
