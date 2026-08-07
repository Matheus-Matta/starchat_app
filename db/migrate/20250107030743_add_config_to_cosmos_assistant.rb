class AddConfigToCosmosAssistant < ActiveRecord::Migration[7.0]
  def change
    add_column :cosmos_assistants, :config, :jsonb, default: {}, null: false
  end
end
