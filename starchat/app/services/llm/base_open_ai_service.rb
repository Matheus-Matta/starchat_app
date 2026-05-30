class Llm::BaseOpenAiService < Llm::BaseAiService
  include Integrations::LlmInstrumentation

  DEFAULT_MODEL = 'gpt-4o-mini'.freeze
  attr_reader :client, :model

  def initialize
    @client = OpenAI::Client.new(
      access_token: InstallationConfig.find_by!(name: 'COSMOS_OPEN_AI_API_KEY').value,
      uri_base: uri_base,
      log_errors: Rails.env.development?
    )
    setup_model
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
    config_value = InstallationConfig.find_by(name: 'COSMOS_OPEN_AI_MODEL')&.value
    @model = (config_value.presence || DEFAULT_MODEL)
  end
end
