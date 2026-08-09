class Llm::BaseAiService
  DEFAULT_MODEL = Llm::Config::DEFAULT_MODEL
  DEFAULT_TEMPERATURE = 1.0

  attr_reader :model, :temperature

  def initialize(feature: nil, account: nil, fallback_model: nil)
    @llm_feature = feature
    @llm_account = account
    @fallback_model = fallback_model

    Llm::Config.initialize!
    setup_model
    setup_temperature
  end

  def chat(model: @model, temperature: @temperature)
    RubyLLM.chat(model: model).with_temperature(temperature)
  end

  private

  def sanitize_json_response(content)
    return nil if content.nil?

    # Upstream's form: handles any ```lang fence, not just ```json.
    content.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end

  def setup_model
    route = feature_route
    return @model = route[:model] if account_override_route?(route) || cosmos_v2_assistant?

    @model = @fallback_model.presence || installation_model.presence || route&.dig(:model) || DEFAULT_MODEL
  end

  def feature_route
    return if @llm_feature.blank?

    Llm::FeatureRouter.resolve(feature: @llm_feature, account: @llm_account)
  end

  def account_override_route?(route)
    route&.dig(:source) == :account_override
  end

  def cosmos_v2_assistant?
    @llm_feature.to_s == 'assistant' && @llm_account&.feature_enabled?('cosmos_integration_v2')
  end

  def installation_model
    InstallationConfig.find_by(name: 'COSMOS_OPEN_AI_MODEL')&.value
  end

  def setup_temperature
    @temperature = DEFAULT_TEMPERATURE
  end
end
