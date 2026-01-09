class AddSenderConfigToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :sender_config, :jsonb
  end
end
