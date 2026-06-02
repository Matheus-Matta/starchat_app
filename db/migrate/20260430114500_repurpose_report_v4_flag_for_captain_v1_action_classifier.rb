class RepurposeReportV4FlagForCosmosV1ActionClassifier < ActiveRecord::Migration[7.1]
  def up
    Account.feature_cosmos_v1_action_classifier.find_each(batch_size: 100) do |account|
      account.disable_features(:cosmos_v1_action_classifier)
      account.save!(validate: false)
    end

    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config&.value.blank?

    config.value = config.value.reject { |feature| feature['name'] == 'report_v4' }
    config.save!
    GlobalConfig.clear_cache
  end
end
