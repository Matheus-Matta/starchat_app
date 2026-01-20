class ConvertDocumentToPolymorphicAssociation < ActiveRecord::Migration[7.0]
  def up
    add_column :cosmos_assistant_responses, :documentable_type, :string

    if ChatwootApp.enterprise?
      Cosmos::AssistantResponse
        .where
        .not(document_id: nil)
        .update_all(documentable_type: 'Cosmos::Document')
    end
    # rubocop:enable Rails/SkipsModelValidations
    remove_index :cosmos_assistant_responses, :document_id if index_exists?(
      :cosmos_assistant_responses, :document_id
    )

    rename_column :cosmos_assistant_responses, :document_id, :documentable_id
    add_index :cosmos_assistant_responses, [:documentable_id, :documentable_type],
              name: 'idx_cap_asst_resp_on_documentable'
  end

  def down
    if index_exists?(
      :cosmos_assistant_responses, [:documentable_id, :documentable_type], name: 'idx_cap_asst_resp_on_documentable'
    )
      remove_index :cosmos_assistant_responses, name: 'idx_cap_asst_resp_on_documentable'
    end

    rename_column :cosmos_assistant_responses, :documentable_id, :document_id
    remove_column :cosmos_assistant_responses, :documentable_type
    add_index :cosmos_assistant_responses, :document_id unless index_exists?(
      :cosmos_assistant_responses, :document_id
    )
  end
end
