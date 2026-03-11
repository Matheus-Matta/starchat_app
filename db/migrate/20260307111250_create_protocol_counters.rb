class CreateProtocolCounters < ActiveRecord::Migration[7.1]
  def change
    create_table :protocol_counters do |t|
      t.references :protocol_policy, null: false, foreign_key: true
      t.date :date
      t.integer :last_seq, default: 0, null: false

      t.timestamps
    end
    add_index :protocol_counters, [:protocol_policy_id, :date], unique: true
  end
end
