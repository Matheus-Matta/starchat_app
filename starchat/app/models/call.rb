class Call < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :conversation
  belongs_to :contact
  belongs_to :message, optional: true
  belongs_to :accepted_by_agent, class_name: 'User', optional: true

  enum :provider, { twilio: 0 }
  enum :direction, { inbound: 0, outbound: 1 }, prefix: :direction

  validates :provider_call_id, presence: true
  validates :direction, presence: true
  validates :status, presence: true
end
