module Starchat::Concerns::User
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_installation_pricing_plan_quantity, on: :create

    has_many :cosmos_::responses, class_name: 'Cosmos::AssistantResponse', dependent: :nullify, as: :documentable
    has_many :copilot_threads, dependent: :destroy_async
  end

  def ensure_installation_pricing_plan_quantity
    return unless ChatwootHub.pricing_plan == 'Enterprise'

    errors.add(:base, 'User limit reached. Please purchase more licenses from super admin') if User.count >= ChatwootHub.pricing_plan_quantity
  end
end
