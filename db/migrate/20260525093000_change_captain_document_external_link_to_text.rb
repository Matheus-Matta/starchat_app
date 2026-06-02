class ChangeCosmosDocumentExternalLinkToText < ActiveRecord::Migration[7.0]
  OLD_INDEX_NAME = 'index_cosmos_documents_on_assistant_id_and_external_link'.freeze
  NEW_INDEX_NAME = 'idx_cosmos_documents_on_assistant_id_and_external_link_md5'.freeze

  def up
    remove_index :cosmos_documents, name: OLD_INDEX_NAME, if_exists: true
    change_column :cosmos_documents, :external_link, :text, null: false
    add_index :cosmos_documents, 'assistant_id, md5(external_link)', unique: true, name: NEW_INDEX_NAME, if_not_exists: true
  end

  def down
    remove_index :cosmos_documents, name: NEW_INDEX_NAME, if_exists: true
    change_column :cosmos_documents, :external_link, :string, null: false
    add_index :cosmos_documents, [:assistant_id, :external_link], unique: true, name: OLD_INDEX_NAME, if_not_exists: true
  end
end
