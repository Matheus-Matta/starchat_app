module Starchat::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :cosmos_inbox, dependent: :destroy, class_name: 'CosmosInbox'
    has_one :cosmos_assistant,
            through: :cosmos_inbox,
            class_name: 'Cosmos::Assistant'
  end
end
