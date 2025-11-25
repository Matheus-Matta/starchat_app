class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string unless column_exists?(:conversations, :cached_label_list)
  end
end
