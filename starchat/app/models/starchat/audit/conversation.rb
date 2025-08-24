module Starchat::Audit::Conversation
  extend ActiveSupport::Concern

  included do
    audited only: [], on: [:destroy]
  end
end
