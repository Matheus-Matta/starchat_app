class AddStatusToCosmosAssistantResponses < ActiveRecord::Migration[7.0]
  def change
    add_column :cosmos_assistant_responses, :status, :integer, default: 1, null: false
    add_index :cosmos_assistant_responses, :status
  end
end
