module Starchat::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :cosmos_::inbox, dependent: :destroy, class_name: 'CosmosInbox'
    has_one :cosmos_::assistant,
            through: :cosmos_::inbox,
            class_name: 'Cosmos::Assistant'
  end
end
