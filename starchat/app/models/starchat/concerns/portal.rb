module Starchat::Concerns::Portal
  extend ActiveSupport::Concern

  included do
    after_save :enqueue_domain_verification, if: :saved_change_to_custom_domain?
  end

  def enqueue_domain_verification
    return if custom_domain.blank?

  end
end
