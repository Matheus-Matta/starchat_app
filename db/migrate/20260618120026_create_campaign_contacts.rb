class CreateCampaignContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :campaign_contacts do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :sent_at
      t.text :error_message

      t.timestamps
    end

    add_index :campaign_contacts, [:campaign_id, :contact_id], unique: true
  end
end
