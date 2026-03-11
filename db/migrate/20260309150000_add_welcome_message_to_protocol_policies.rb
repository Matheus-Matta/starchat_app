class AddWelcomeMessageToProtocolPolicies < ActiveRecord::Migration[7.1]
  def change
    add_column :protocol_policies, :welcome_message, :text
  end
end
