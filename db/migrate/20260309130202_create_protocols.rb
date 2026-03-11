class CreateProtocols < ActiveRecord::Migration[7.1]
  def up
    create_table :protocols do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :protocol_policy, null: false, foreign_key: true
      t.string :code, null: false
      t.integer :seq, null: false
      t.date :date, null: false
      t.string :problem
      t.text :description

      t.timestamps
    end

    add_index :protocols, :code, unique: true

    # Migrate existing protocol associations from conversations
    execute <<-SQL
      INSERT INTO protocols (account_id, conversation_id, protocol_policy_id, code, seq, date, created_at, updated_at)
      SELECT account_id, id, protocol_policy_id, protocol_code, protocol_seq, protocol_date, created_at, updated_at
      FROM conversations
      WHERE protocol_code IS NOT NULL AND protocol_policy_id IS NOT NULL
    SQL
  end

  def down
    drop_table :protocols
  end
end
