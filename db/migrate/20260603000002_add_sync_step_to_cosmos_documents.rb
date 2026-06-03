class AddSyncStepToCosmosDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :cosmos_documents, :sync_step, :string unless column_exists?(:cosmos_documents, :sync_step)
  end
end
