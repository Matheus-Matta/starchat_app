class AddMetadataToCosmosDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :cosmos_documents, :metadata, :jsonb, default: {}
  end
end
