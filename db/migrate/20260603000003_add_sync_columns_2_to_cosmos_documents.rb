class AddSyncColumns2ToCosmosDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :cosmos_documents, :content_fingerprint, :string unless column_exists?(:cosmos_documents, :content_fingerprint)
  end
end
