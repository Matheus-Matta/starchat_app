# db/migrate/20250830000000_change_channel_evolution_state_to_string.rb
class ChangeChannelEvolutionStateToString < ActiveRecord::Migration[7.1]
  def up
    add_column :channel_evolution, :state_text, :string, null: false, default: 'disconnected'

    execute <<~SQL.squish
      UPDATE channel_evolution
      SET state_text = CASE state
        WHEN 0 THEN 'disconnected'
        WHEN 1 THEN 'connecting'
        WHEN 2 THEN 'qrcode'
        WHEN 3 THEN 'pairing'
        WHEN 4 THEN 'open'
        WHEN 5 THEN 'error'
        ELSE 'disconnected'
      END
    SQL

    remove_index  :channel_evolution, :state if index_exists?(:channel_evolution, :state)
    remove_column :channel_evolution, :state
    rename_column :channel_evolution, :state_text, :state
    add_index     :channel_evolution, :state
  end

  def down
    add_column :channel_evolution, :state_int, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE channel_evolution
      SET state_int = CASE state
        WHEN 'disconnected' THEN 0
        WHEN 'connecting'   THEN 1
        WHEN 'qrcode'       THEN 2
        WHEN 'pairing'      THEN 3
        WHEN 'open'         THEN 4
        WHEN 'error'        THEN 5
        ELSE 0
      END
    SQL

    remove_index  :channel_evolution, :state if index_exists?(:channel_evolution, :state)
    remove_column :channel_evolution, :state
    rename_column :channel_evolution, :state_int, :state
    add_index     :channel_evolution, :state
  end
end
