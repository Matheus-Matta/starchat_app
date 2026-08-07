class AddResponseGuidelinesAndGuardrailsToCosmosAssistants < ActiveRecord::Migration[7.1]
  def change
    add_column :cosmos_assistants, :response_guidelines, :jsonb, default: []
    add_column :cosmos_assistants, :guardrails, :jsonb, default: []
  end
end
