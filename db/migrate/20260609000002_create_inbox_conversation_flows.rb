class CreateInboxConversationFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :inbox_conversation_flows do |t|
      t.references :inbox,             null: false, foreign_key: true, index: { unique: true }
      t.references :conversation_flow, null: false, foreign_key: true
      t.timestamps
    end
  end
end
