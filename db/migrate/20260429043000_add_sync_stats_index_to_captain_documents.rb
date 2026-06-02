class AddSyncStatsIndexToCosmosDocuments < ActiveRecord::Migration[7.0]
  def up
    add_index :cosmos_documents,
              [:account_id, :assistant_id, :sync_status, :last_synced_at],
              name: 'idx_cosmos_documents_on_account_assistant_sync_stats',
              if_not_exists: true
  end

  def down
    remove_index :cosmos_documents, name: 'idx_cosmos_documents_on_account_assistant_sync_stats', if_exists: true
  end
end
