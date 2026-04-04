# frozen_string_literal: true

class CreateContactResponsibleAgents < ActiveRecord::Migration[7.0]
  def up
    create_table :contact_responsible_agents do |t|
      t.references :contact, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.timestamps
    end

    add_index :contact_responsible_agents, %i[contact_id user_id], unique: true

    # Migrate existing single responsible_agent_id to the new join table
    execute <<~SQL
      INSERT INTO contact_responsible_agents (contact_id, user_id, created_at, updated_at)
      SELECT id, responsible_agent_id, NOW(), NOW()
      FROM contacts
      WHERE responsible_agent_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    remove_reference :contacts, :responsible_agent, foreign_key: { to_table: :users }, index: true
  end

  def down
    add_reference :contacts, :responsible_agent, foreign_key: { to_table: :users }, index: true, null: true

    # Restore the first responsible agent (oldest) to the legacy column
    execute <<~SQL
      UPDATE contacts
      SET responsible_agent_id = (
        SELECT user_id
        FROM contact_responsible_agents
        WHERE contact_id = contacts.id
        ORDER BY created_at ASC
        LIMIT 1
      )
    SQL

    drop_table :contact_responsible_agents
  end
end
