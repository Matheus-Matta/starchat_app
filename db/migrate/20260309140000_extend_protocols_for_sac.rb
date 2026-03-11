class ExtendProtocolsForSac < ActiveRecord::Migration[7.1]
  def up
    # Adiciona contact_id ao protocols (link direto contato ↔ protocolo SAC)
    add_reference :protocols, :contact, null: true, foreign_key: true, index: true

    # Status do protocolo (independente do status da conversa)
    # 0 = open, 1 = closed, 2 = archived
    add_column :protocols, :status, :integer, default: 0, null: false

    # Motivo/razão da abertura do protocolo (agente preenche)
    add_column :protocols, :reason, :string, limit: 500

    # Quando foi encerrado
    add_column :protocols, :closed_at, :datetime

    # Torna conversation_id nullable (protocolo agora pode abranger múltiplas conversas)
    change_column_null :protocols, :conversation_id, true

    # Cria tabela de comentários/anotações do protocolo (padrão SAC)
    create_table :protocol_comments do |t|
      t.references :protocol,  null: false, foreign_key: true, index: true
      t.references :account,   null: false, foreign_key: true, index: true
      t.references :user,      null: true,  foreign_key: true, index: true   # agente
      t.text    :content,      null: false
      t.boolean :is_private,   default: false, null: false   # comentário interno
      t.timestamps
    end

    # Vincula conversas ao protocolo diretamente (protocolo pode ter N conversas)
    add_reference :conversations, :protocol, null: true, foreign_key: true, index: true

    # Migra dados existentes: preenche conversations.protocol_id via join por protocol_code
    execute <<-SQL
      UPDATE conversations c
      SET protocol_id = p.id
      FROM protocols p
      WHERE p.conversation_id = c.id
        AND c.protocol_code IS NOT NULL
    SQL

    # Preenche contact_id nos protocolos via conversations já vinculadas
    execute <<-SQL
      UPDATE protocols p
      SET contact_id = c.contact_id
      FROM conversations c
      WHERE p.conversation_id = c.id
        AND p.contact_id IS NULL
    SQL

    # Adiciona índice de busca por (contact_id, status) para lookup rápido na reutilização
    add_index :protocols, [:contact_id, :status]
    add_index :protocols, [:protocol_policy_id, :contact_id, :status],
              name: 'idx_protocols_policy_contact_status'
  end

  def down
    remove_index  :protocols, name: 'idx_protocols_policy_contact_status'
    remove_index  :protocols, [:contact_id, :status]

    remove_reference :conversations, :protocol

    drop_table :protocol_comments

    change_column_null :protocols, :conversation_id, false

    remove_column :protocols, :closed_at
    remove_column :protocols, :reason
    remove_column :protocols, :status
    remove_reference :protocols, :contact
  end
end
