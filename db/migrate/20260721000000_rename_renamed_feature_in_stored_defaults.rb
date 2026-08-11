class RenameRenamedFeatureInStoredDefaults < ActiveRecord::Migration[7.1]
  # ACCOUNT_LEVEL_FEATURE_DEFAULTS stores feature names, not bit positions, so renaming
  # a feature in config/features.yml leaves the stored copy pointing at a name that no
  # longer has an accessor. enable_default_features then raises NoMethodError on every
  # account creation.
  RENAMES = { 'contact_chatwoot_support_team' => 'contact_starchats_support_team' }.freeze
  CONFIG_NAME = 'ACCOUNT_LEVEL_FEATURE_DEFAULTS'.freeze

  def up
    rewrite(RENAMES)
  end

  def down
    rewrite(RENAMES.invert)
  end

  private

  def rewrite(mapping)
    config = InstallationConfig.find_by(name: CONFIG_NAME)
    return if config.blank?

    features = config.value
    return unless features.is_a?(Array)

    changed = false
    features.each do |feature|
      next unless feature.is_a?(Hash)

      replacement = mapping[feature['name']]
      next if replacement.blank?

      feature['name'] = replacement
      changed = true
    end

    config.update!(value: features) if changed
  end
end
