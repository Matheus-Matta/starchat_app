# frozen_string_literal: true

# Move equal_distribution config from assignment_policies (conta compartilhada)
# para inbox_assignment_policies (configuração por inbox).
#
# Também adiciona `equal_distribution_balance_threshold`:
#   Define o limiar em % de diferença de carga entre agentes.
#   Se a dispersão estiver abaixo do limiar, usa round-robin em vez da distribuição igualitária.
#   Ex.: threshold=20 → se todos os agentes tiverem entre 8-12 cvs (dispersão ~33%) usa equal;
#                        se tiverem entre 10-12 (dispersão ~16%), ignora e usa round-robin.
class MoveEqualDistributionToInboxAssignmentPolicies < ActiveRecord::Migration[7.1]
  def change
    # Remove da tabela de política compartilhada (nível de conta)
    remove_column :assignment_policies, :equal_distribution_enabled, :boolean
    remove_column :assignment_policies, :equal_distribution_window_hours, :integer

    # Adiciona na tabela de vínculo por inbox
    add_column :inbox_assignment_policies, :equal_distribution_enabled, :boolean, null: false, default: false
    add_column :inbox_assignment_policies, :equal_distribution_window_hours, :integer, null: false, default: 24
    # Limiar de % — se a dispersão de carga entre agentes for <= threshold, usa round-robin
    add_column :inbox_assignment_policies, :equal_distribution_balance_threshold, :integer, null: false, default: 20
  end
end
