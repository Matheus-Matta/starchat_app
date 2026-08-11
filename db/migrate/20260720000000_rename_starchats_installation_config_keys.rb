class RenameStarchatsInstallationConfigKeys < ActiveRecord::Migration[7.1]
  # These keys are stored by name in installation_configs, so renaming them in
  # config/installation_config.yml alone would orphan the values an installation has
  # already set — the app would read the new name, find nothing, and silently fall back
  # to defaults. Mirrors 20260503000000, which did the same for the CAPTAIN_* keys.
  KEY_RENAMES = {
    'CHATWOOT_INBOX_TOKEN' => 'STARCHATS_INBOX_TOKEN',
    'CHATWOOT_INBOX_HMAC_KEY' => 'STARCHATS_INBOX_HMAC_KEY',
    'CHATWOOT_INSTANCE_ADMIN_EMAIL' => 'STARCHATS_INSTANCE_ADMIN_EMAIL'
  }.freeze

  def up
    rename_keys(KEY_RENAMES)
  end

  def down
    rename_keys(KEY_RENAMES.invert)
  end

  private

  def rename_keys(mapping)
    mapping.each do |from, to|
      # Skip when the destination already exists, so re-running cannot raise on the
      # unique index over name.
      next if InstallationConfig.exists?(name: to)

      InstallationConfig.where(name: from).update_all(name: to) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
