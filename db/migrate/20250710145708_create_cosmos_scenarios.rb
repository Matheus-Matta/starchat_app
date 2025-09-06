class CreateCosmosScenarios < ActiveRecord::Migration[7.1]
  def change
    create_table :cosmos_scenarios do |t|
      t.string :title
      t.text :description
      t.text :instruction
      t.jsonb :tools, default: []
      t.boolean :enabled, default: true, null: false
      t.references :assistant, null: false
      t.references :account, null: false

      t.timestamps
    end

          add_index :cosmos_scenarios, :enabled
      add_index :cosmos_scenarios, [:assistant_id, :enabled]
  end
end
