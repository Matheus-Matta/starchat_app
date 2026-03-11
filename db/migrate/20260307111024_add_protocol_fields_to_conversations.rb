class AddProtocolFieldsToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :protocol_code, :string
    add_index :conversations, :protocol_code, unique: true
    add_column :conversations, :protocol_seq, :integer
    add_column :conversations, :protocol_date, :date
    add_reference :conversations, :protocol_policy, null: true, foreign_key: true
  end
end
