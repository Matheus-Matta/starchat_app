module Starchat::Concerns::AssignmentPolicy
  extend ActiveSupport::Concern

  included do
    enum assignment_order: { round_robin: 0, balanced: 1, equal_distribution: 2 } if StarchatsApp.enterprise?
  end
end
