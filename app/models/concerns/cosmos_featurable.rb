# frozen_string_literal: true

module CosmosFeaturable
  extend ActiveSupport::Concern

  included do
    validate :validate_cosmos_models

    # Dynamically define accessor methods for each cosmos feature
    Llm::Models.feature_keys.each do |feature_key|
      # Define enabled? methods (e.g., cosmos_editor_enabled?)
      define_method("cosmos_#{feature_key}_enabled?") do
        cosmos_features_with_defaults[feature_key]
      end

      # Define model accessor methods (e.g., cosmos_editor_model)
      define_method("cosmos_#{feature_key}_model") do
        cosmos_models_with_defaults[feature_key]
      end
    end
  end

  def cosmos_preferences
    {
      models: cosmos_models_with_defaults,
      features: cosmos_features_with_defaults
    }.with_indifferent_access
  end

  private

  def cosmos_models_with_defaults
    stored_models = cosmos_models || {}
    Llm::Models.feature_keys.each_with_object({}) do |feature_key, result|
      stored_value = stored_models[feature_key]
      result[feature_key] = if stored_value.present? && Llm::Models.valid_model_for?(feature_key, stored_value)
                              stored_value
                            else
                              Llm::Models.default_model_for(feature_key)
                            end
    end
  end

  def cosmos_features_with_defaults
    stored_features = cosmos_features || {}
    Llm::Models.feature_keys.index_with do |feature_key|
      stored_features[feature_key] == true
    end
  end

  def validate_cosmos_models
    return if cosmos_models.blank?

    cosmos_models.each do |feature_key, model_name|
      next if model_name.blank?
      next if Llm::Models.valid_model_for?(feature_key, model_name)

      allowed_models = Llm::Models.models_for(feature_key)
      errors.add(:cosmos_models, "'#{model_name}' is not a valid model for #{feature_key}. Allowed: #{allowed_models.join(', ')}")
    end
  end
end
