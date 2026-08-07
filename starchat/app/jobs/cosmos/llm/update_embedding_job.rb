class Cosmos::Llm::UpdateEmbeddingJob < ApplicationJob
  queue_as :low

  def perform(record, content)
    embedding = Cosmos::Llm::EmbeddingService.new.get_embedding(content)
    record.update!(embedding: embedding)
  end
end
