class ChangeCosmosAssistantDescriptionToText < ActiveRecord::Migration[7.0]
  def up
    change_column :cosmos_assistants, :description, :text
  end

  def down
    change_column :cosmos_assistants, :description, :string
  end
end
