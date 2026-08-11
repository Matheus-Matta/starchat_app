class Llm::BaseOpenAiService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  DEFAULT_MODEL = 'gpt-4o-mini'.freeze
  attr_reader :client, :model

  # Accepts the same routing arguments as the parent so subclasses that need both the
  # OpenAI client and account-level model overrides can have them. Every argument stays
  # optional, so existing `super()` callers keep the global default model.
  def initialize(feature: nil, account: nil, fallback_model: nil)
    @client = OpenAI::Client.new(
      access_token: InstallationConfig.find_by!(name: 'COSMOS_OPEN_AI_API_KEY').value,
      uri_base: uri_base,
      log_errors: Rails.env.development?
    )
    super
  rescue StandardError => e
    raise "Failed to initialize OpenAI client: #{e.message}"
  end

  # Creates a RubyLLM::Chat instance configured with the system API key.
  # Used by Cosmos::ChatHelper and other concerns that need a RubyLLM chat object.
  def chat(model: @model, temperature: nil)
    Llm::Config.initialize!
    llm_chat = RubyLLM.chat(model: model)
    temperature.present? ? llm_chat.with_temperature(temperature.to_f) : llm_chat
  end

  private

  def uri_base
    endpoint = InstallationConfig.find_by(name: 'COSMOS_OPEN_AI_ENDPOINT')&.value
    endpoint.presence || 'https://api.openai.com/'
  end

  def setup_model
    # When a feature is configured, defer to the parent's routing so account-level
    # overrides and per-feature defaults apply. Without one there is nothing to route
    # on, so keep the legacy global installation model.
    return super if @llm_feature.present?

    config_value = InstallationConfig.find_by(name: 'COSMOS_OPEN_AI_MODEL')&.value
    @model = (config_value.presence || DEFAULT_MODEL)
  end
end
