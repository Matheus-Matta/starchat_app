# == Schema Information
#
# Table name: protocol_comments
#
#  id          :bigint           not null, primary key
#  content     :text             not null
#  is_private  :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  protocol_id :bigint           not null
#  user_id     :bigint
#
# Indexes
#
#  index_protocol_comments_on_account_id   (account_id)
#  index_protocol_comments_on_protocol_id  (protocol_id)
#  index_protocol_comments_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (protocol_id => protocols.id)
#  fk_rails_...  (user_id => users.id)
#

class ProtocolComment < ApplicationRecord
  belongs_to :account
  belongs_to :protocol
  belongs_to :user, optional: true  # agente que registrou

  # Arquivos anexados ao comentário (padrão SAC: evidências, fotos, NF, etc.)
  has_many_attached :files

  validates :content, presence: true, length: { maximum: 10_000 }

  scope :public_only,  -> { where(is_private: false) }
  scope :private_only, -> { where(is_private: true) }
end
