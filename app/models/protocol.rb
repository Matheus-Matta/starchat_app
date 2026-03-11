# == Schema Information
#
# Table name: protocols
#
#  id                 :bigint           not null, primary key
#  closed_at          :datetime
#  code               :string           not null
#  date               :date             not null
#  description        :text
#  problem            :string
#  reason             :string(500)
#  seq                :integer          not null
#  status             :integer          default("open"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  contact_id         :bigint
#  conversation_id    :bigint
#  protocol_policy_id :bigint           not null
#
# Indexes
#
#  idx_protocols_policy_contact_status       (protocol_policy_id,contact_id,status)
#  index_protocols_on_account_id             (account_id)
#  index_protocols_on_code                   (code) UNIQUE
#  index_protocols_on_contact_id             (contact_id)
#  index_protocols_on_contact_id_and_status  (contact_id,status)
#  index_protocols_on_conversation_id        (conversation_id)
#  index_protocols_on_protocol_policy_id     (protocol_policy_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (protocol_policy_id => protocol_policies.id)
#

class Protocol < ApplicationRecord
  # Pundit usa ProtocolSacPolicy para evitar conflito de nomes com o model ProtocolPolicy.
  def self.policy_class
    ProtocolSacPolicy
  end

  # Status do protocolo (independente do status da conversa)
  enum status: { open: 0, closed: 1, archived: 2 }

  belongs_to :account
  belongs_to :contact,         optional: true
  belongs_to :conversation,    optional: true   # conversa de origem
  belongs_to :protocol_policy

  # Um protocolo pode abranger múltiplas conversas quando reutilizado pelo contato
  has_many :conversations, foreign_key: :protocol_id, dependent: :nullify, inverse_of: :protocol
  has_many :protocol_comments, dependent: :destroy

  # Anexos diretos via ActiveStorage (documentos, imagens, etc.)
  has_many_attached :files

  validates :code,   presence: true, uniqueness: true
  validates :seq,    presence: true
  validates :date,   presence: true
  validates :reason, length: { maximum: 500 }, allow_blank: true

  scope :open_for_contact, ->(contact_id, policy_id) {
    where(contact_id: contact_id, protocol_policy_id: policy_id, status: :open)
  }

  # Retorna o protocolo aberto mais recente do contato para uma dada política
  def self.find_open_for_contact(contact_id, policy_id)
    open_for_contact(contact_id, policy_id).order(created_at: :desc).first
  end

  def close!
    update!(status: :closed, closed_at: Time.current)
  end

  def reopen!
    update!(status: :open, closed_at: nil)
  end
end
