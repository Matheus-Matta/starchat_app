class AddAntiSpamConfigToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :anti_spam_config, :jsonb
  end
end
