class CreateChannelEvolution < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_evolution do |t|
      t.integer :account_id, null: false
      t.string  :instance_name
      t.string  :api_key
      t.string  :webhook_url
      t.string  :webhook_secret
      t.jsonb   :provider_config, null: false, default: {}
      t.timestamps
    end
    add_index  :channel_evolution, :account_id
    add_index  :channel_evolution, :instance_name, unique: true
    add_column :channel_evolution, :state, :integer, null: false, default: 0
    add_column :channel_evolution, :state_updated_at, :datetime
    add_index  :channel_evolution, :state
  end
end
