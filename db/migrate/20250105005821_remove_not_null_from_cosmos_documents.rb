class RemoveNotNullFromCosmosDocuments < ActiveRecord::Migration[7.0]
  def change
    change_column_null :cosmos_documents, :name, true
  end
end
