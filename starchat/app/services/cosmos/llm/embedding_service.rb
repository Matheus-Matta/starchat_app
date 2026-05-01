class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

class Cosmos::Llm::EmbeddingService < Llm::BaseOpenAiService
  class EmbeddingsError < StandardError; end

  def self.embedding_model
    @embedding_model = InstallationConfig.find_by(name: 'COSMOS_EMBEDDING_MODEL')&.value.presence || OpenAiConstants::DEFAULT_EMBEDDING_MODEL
  end

  def self.embedding_model
    InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def get_embedding(content, model: @embedding_model)
    return [] if content.blank?

    instrument_embedding_call(instrumentation_params(content, model)) do
      RubyLLM.embed(content, model: model).vectors
    end
  rescue RubyLLM::Error => e
    Rails.logger.error "Embedding API Error: #{e.message}"
    raise EmbeddingsError, "Failed to create an embedding: #{e.message}"
  end

  private

  def instrumentation_params(content, model)
    {
      span_name: 'llm.captain.embedding',
      model: model,
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end
end
