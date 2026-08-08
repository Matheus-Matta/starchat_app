module Starchat::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :cosmos_inbox, dependent: :destroy, class_name: 'CosmosInbox'
    has_one :cosmos_assistant,
            through: :cosmos_inbox,
            class_name: 'Cosmos::Assistant'
    has_many :inbox_capacity_limits, dependent: :destroy
    has_many :calls, dependent: :destroy_async

    before_create :ensure_create_permitted
  end

  def ensure_create_permitted
    raise CustomExceptions::Inbox::LimitExceeded.new({}) if account.inboxes.count >= account.usage_limits[:inboxes]
  end
end
