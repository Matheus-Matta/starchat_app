class CreateConversationFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_flows do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :name, null: false
      t.boolean :enabled, default: true, null: false
      t.integer :auto_resolve_duration
      t.text    :auto_resolve_message
      t.boolean :auto_resolve_ignore_waiting, default: false
      t.string  :no_client_interaction_label
      t.string  :no_agent_interaction_label
      t.text    :reengagement_message
      t.integer :reengagement_interval
      t.timestamps
    end

    add_index :conversation_flows, [:account_id, :enabled]
  end
end
