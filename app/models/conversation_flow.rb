# == Schema Information
#
# Table name: conversation_flows
#
#  id                          :bigint           not null, primary key
#  auto_resolve_duration       :integer
#  auto_resolve_ignore_waiting :boolean          default(FALSE)
#  auto_resolve_message        :text
#  enabled                     :boolean          default(TRUE), not null
#  name                        :string           not null
#  no_agent_interaction_label  :string
#  no_client_interaction_label :string
#  reengagement_interval       :integer
#  reengagement_message        :text
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#
# Indexes
#
#  index_conversation_flows_on_account_id              (account_id)
#  index_conversation_flows_on_account_id_and_enabled  (account_id,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

class ConversationFlow < ApplicationRecord
  REENGAGEMENT_INTERVAL_MIN = 5

  belongs_to :account
  has_many :inbox_conversation_flows, dependent: :destroy
  has_many :inboxes, through: :inbox_conversation_flows

  validates :name, presence: true
  validates :reengagement_interval,
            numericality: { only_integer: true, greater_than_or_equal_to: REENGAGEMENT_INTERVAL_MIN },
            allow_nil: true
  validates :auto_resolve_duration,
            numericality: { only_integer: true, greater_than: 0 },
            allow_nil: true

  scope :active,            -> { where(enabled: true) }
  scope :with_reengagement, -> { active.where.not(reengagement_interval: nil).where.not(reengagement_message: [nil, '']) }
  scope :with_auto_resolve, -> { active.where.not(auto_resolve_duration: nil) }

  def reengagement_active?
    enabled? && reengagement_interval.present? && reengagement_message.present?
  end

  def auto_resolve_active?
    enabled? && auto_resolve_duration.to_i.positive?
  end

  def interaction_label_for(conversation)
    conversation.waiting_since.present? ? no_agent_interaction_label : no_client_interaction_label
  end
end
