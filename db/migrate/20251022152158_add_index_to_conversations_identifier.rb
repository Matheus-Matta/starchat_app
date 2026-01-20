class AddIndexToConversationsIdentifier < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    return if index_exists?(:conversations, [:identifier, :account_id], name: 'index_conversations_on_identifier_and_account_id')

    add_index :conversations, [:identifier, :account_id], name: 'index_conversations_on_identifier_and_account_id', algorithm: :concurrently
  end
end
