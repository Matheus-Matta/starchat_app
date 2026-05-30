class GlobalConfigService
  def self.load(config_key, default_value)
    env_value = ENV.fetch(config_key, nil)
    return env_value if env_value.present?

    config = GlobalConfig.get(config_key)[config_key]
    return config if config.present?

    # To support migrating existing instance relying on env variables
    # TODO: deprecate this later down the line
    config_value = ENV.fetch(config_key) { default_value }

    return if config_value.blank?

    i = InstallationConfig.where(name: config_key).first_or_create(value: config_value, locked: false)
    # To clear a nil value that might have been cached in the previous call
    GlobalConfig.clear_cache
    i.value
  end

  def self.account_signup_enabled?
    # Read from ENV first so with_modified_env in specs works correctly,
    # then fall back to InstallationConfig via GlobalConfig.
    env_value = ENV.fetch('ENABLE_ACCOUNT_SIGNUP', nil)
    value = env_value.presence || GlobalConfig.get('ENABLE_ACCOUNT_SIGNUP')['ENABLE_ACCOUNT_SIGNUP'].to_s
    value == 'true' || value == 'api_only'
  end
end
