class CreateCosmosInbox < ActiveRecord::Migration[7.0]
  def change
    create_table :cosmos_inboxes do |t|
      t.references :cosmos_assistant, null: false
      t.references :inbox, null: false
      t.timestamps
    end

          add_index :cosmos_inboxes, [:cosmos_assistant_id, :inbox_id], unique: true
  end
end
