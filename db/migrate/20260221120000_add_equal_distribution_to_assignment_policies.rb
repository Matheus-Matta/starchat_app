# frozen_string_literal: true

class AddEqualDistributionToAssignmentPolicies < ActiveRecord::Migration[7.1]
  def change
    add_column :assignment_policies, :equal_distribution_enabled, :boolean, null: false, default: false
    add_column :assignment_policies, :equal_distribution_window_hours, :integer, null: false, default: 24
  end
end
