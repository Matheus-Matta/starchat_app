class CreateProtocolPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :protocol_policies do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :prefix, null: false
      t.integer :scope, default: 0
      t.integer :seq_padding, default: 4
      t.boolean :include_store_code, default: false
      t.boolean :include_city_code, default: false
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
