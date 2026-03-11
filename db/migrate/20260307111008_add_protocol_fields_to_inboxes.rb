class AddProtocolFieldsToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_reference :inboxes, :protocol_policy, null: true, foreign_key: true
  end
end
