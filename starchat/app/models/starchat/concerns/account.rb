module Starchat::Concerns::Account
  extend ActiveSupport::Concern

  included do
    has_many :sla_policies, dependent: :destroy_async
    has_many :applied_slas, dependent: :destroy_async
    has_many :custom_roles, dependent: :destroy_async

    has_many :cosmos_::assistants, dependent: :destroy_async, class_name: 'Cosmos::Assistant'
    has_many :cosmos_::assistant_responses, dependent: :destroy_async, class_name: 'Cosmos::AssistantResponse'
    has_many :cosmos_::documents, dependent: :destroy_async, class_name: 'Cosmos::Document'

    has_many :copilot_threads, dependent: :destroy_async
    has_many :voice_channels, dependent: :destroy_async, class_name: '::Channel::Voice'
  end
end
