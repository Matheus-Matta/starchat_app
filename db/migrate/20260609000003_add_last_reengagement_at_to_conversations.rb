class AddLastReengagementAtToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :last_reengagement_at, :datetime
    add_index  :conversations, :last_reengagement_at
  end
end
