module Starchat::Concerns::Inbox
  extend ActiveSupport::Concern

  included do
    has_one :captain_inbox, dependent: :destroy, class_name: 'CosmosInbox'
    has_one :captain_assistant,
            through: :captain_inbox,
            class_name: 'Cosmos::Assistant'
  end
end
