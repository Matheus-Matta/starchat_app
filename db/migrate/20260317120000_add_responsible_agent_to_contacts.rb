# frozen_string_literal: true

class AddResponsibleAgentToContacts < ActiveRecord::Migration[7.0]
  def change
    add_reference :contacts, :responsible_agent, foreign_key: { to_table: :users }, index: true, null: true
  end
end
