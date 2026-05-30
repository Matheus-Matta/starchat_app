module Starchat::Concerns::Account
  extend ActiveSupport::Concern

  def cosmos_auto_resolve_mode
    raw = settings['cosmos_auto_resolve_mode'].presence
    return raw if raw

    return 'disabled' if settings['cosmos_disable_auto_resolve'].present?

    feature_enabled?('cosmos_tasks') ? 'evaluated' : 'legacy'
  end

  def cosmos_auto_resolve_mode=(value)
    settings['cosmos_auto_resolve_mode'] = value
  end

  def cosmos_auto_resolve_legacy?    = cosmos_auto_resolve_mode == 'legacy'
  def cosmos_auto_resolve_evaluated? = cosmos_auto_resolve_mode == 'evaluated'
  def cosmos_auto_resolve_disabled?  = cosmos_auto_resolve_mode == 'disabled'

  def cosmos_preferences
    saved_models    = (settings['cosmos_models'] || {}).stringify_keys
    saved_features  = (settings['cosmos_features'] || {}).stringify_keys

    models = Llm::Models.feature_keys.each_with_object({}) do |feature, h|
      h[feature] = saved_models[feature].presence || Llm::Models.default_model_for(feature)
    end

    features = Llm::Models.feature_keys.each_with_object({}) do |feature, h|
      h[feature] = saved_features[feature] == true || saved_features[feature].to_s == 'true' ? true : false
    end

    { models: models, features: features }
  end

  included do
    store_accessor :settings, :conversation_required_attributes
    store_accessor :settings, :cosmos_models, :cosmos_features

    validate :validate_cosmos_models

    has_many :sla_policies, dependent: :destroy_async
    has_many :applied_slas, dependent: :destroy_async
    has_many :custom_roles, dependent: :destroy_async
    has_many :agent_capacity_policies, dependent: :destroy_async

    has_many :cosmos_assistants, dependent: :destroy_async, class_name: 'Cosmos::Assistant'
    has_many :cosmos_assistant_responses, dependent: :destroy_async, class_name: 'Cosmos::AssistantResponse'
    has_many :cosmos_documents, dependent: :destroy_async, class_name: 'Cosmos::Document'
    has_many :cosmos_custom_tools, dependent: :destroy_async, class_name: 'Cosmos::CustomTool'

    has_many :copilot_threads, dependent: :destroy_async
    has_many :companies, dependent: :destroy_async
    has_many :voice_channels, dependent: :destroy_async, class_name: '::Channel::Voice'
    has_many :calls, dependent: :destroy_async

    has_one :saml_settings, dependent: :destroy_async, class_name: 'AccountSamlSettings'
  end

  private

  def validate_cosmos_models
    return if cosmos_models.blank?

    (cosmos_models || {}).each do |feature, model|
      next if model.blank?
      next if Llm::Models.valid_model_for?(feature, model)

      errors.add(:cosmos_models, "#{model} is not a valid model for #{feature}")
    end
  end
end
