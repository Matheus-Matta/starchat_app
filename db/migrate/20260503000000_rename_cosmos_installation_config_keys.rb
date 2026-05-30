class RenameCosmosInstallationConfigKeys < ActiveRecord::Migration[7.0]
  RENAMES = {
    'CAPTAIN_OPEN_AI_API_KEY' => 'COSMOS_OPEN_AI_API_KEY',
    'CAPTAIN_OPEN_AI_ENDPOINT' => 'COSMOS_OPEN_AI_ENDPOINT',
    'CAPTAIN_EMBEDDING_MODEL' => 'COSMOS_EMBEDDING_MODEL',
    'CAPTAIN_CLOUD_PLAN_LIMITS' => 'COSMOS_CLOUD_PLAN_LIMITS'
  }.freeze

  def up
    RENAMES.each do |old_name, new_name|
      InstallationConfig.where(name: old_name).update_all(name: new_name) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    RENAMES.each do |old_name, new_name|
      InstallationConfig.where(name: new_name).update_all(name: old_name) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
