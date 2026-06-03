class AddLastSyncErrorCodeToCosmosDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :cosmos_documents, :last_sync_error_code, :string
  end
end
