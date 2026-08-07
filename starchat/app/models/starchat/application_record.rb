module Starchat::ApplicationRecord
  def droppables
    super + %w[SlaPolicy]
  end
end
