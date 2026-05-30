module Starchat::Concerns::User
  extend ActiveSupport::Concern

  included do
    has_many :cosmos_responses, class_name: 'Cosmos::AssistantResponse', dependent: :nullify, as: :documentable
    has_many :copilot_threads, dependent: :destroy_async
  end
end
