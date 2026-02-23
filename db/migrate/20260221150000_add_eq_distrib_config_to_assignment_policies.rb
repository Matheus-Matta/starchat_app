# frozen_string_literal: true

# Traz a configuração de Equal Distribution de volta para o nível da política
# (assignment_policies), tornando-a compartilhada entre todos os inboxes
# vinculados a uma mesma política.
#
# Os campos em inbox_assignment_policies são mantidos por compatibilidade retroativa.
class AddEqDistribConfigToAssignmentPolicies < ActiveRecord::Migration[7.1]
  def change
    add_column :assignment_policies, :equal_distribution_window_hours, :integer, null: false, default: 24
    add_column :assignment_policies, :equal_distribution_balance_threshold, :integer, null: false, default: 20
  end
end
