class AddAutoResolveToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :auto_resolve_duration, :integer
    add_column :inboxes, :auto_resolve_message, :text
    add_column :inboxes, :auto_resolve_ignore_waiting, :boolean
    add_column :inboxes, :auto_resolve_label, :string
  end
end
