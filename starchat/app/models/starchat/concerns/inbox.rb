module Starchat::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :cosmos_inbox, dependent: :destroy, class_name: 'CosmosInbox'
    has_one :cosmos_assistant,
            through: :cosmos_inbox,
            class_name: 'Cosmos::Assistant'
    has_many :inbox_capacity_limits, dependent: :destroy
    has_many :calls, dependent: :destroy_async
  end
end
