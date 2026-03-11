# == Schema Information
#
# Table name: protocol_policies
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE)
#  include_city_code  :boolean          default(FALSE)
#  include_store_code :boolean          default(FALSE)
#  name               :string           not null
#  prefix             :string           not null
#  scope              :integer          default("daily")
#  seq_padding        :integer          default(4)
#  welcome_message    :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#
# Indexes
#
#  index_protocol_policies_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ProtocolPolicy < ApplicationRecord
  belongs_to :account
  has_many :inboxes, dependent: :nullify
  has_many :conversations, dependent: :nullify

  enum scope: { daily: 0, global: 1 }

  validates :name, presence: true
  validates :prefix, presence: true
  validates :seq_padding, presence: true, numericality: { greater_than: 0 }
end
