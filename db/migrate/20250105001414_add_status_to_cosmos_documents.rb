class AddStatusToCosmosDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :cosmos_documents, :status, :integer, null: false, default: 0
    add_index :cosmos_documents, :status
  end
end
