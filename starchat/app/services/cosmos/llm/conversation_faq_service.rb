class Cosmos::Llm::ConversationFaqService < Llm::BaseOpenAiService
  DISTANCE_THRESHOLD = 0.3
  MATCH_LIMIT = 5
  LLM_FEATURE = 'conversation_faq_generation'.freeze

  def self.language_for(conversation)
    language = conversation.language.presence || conversation.account.locale.presence || I18n.default_locale.to_s
    normalize_language(language)
  end

  def self.normalize_language(language)
    language.to_s.tr('-', '_').split('_').first.downcase
  end

  private_class_method :normalize_language

  def initialize(assistant, conversation)
    super(feature: LLM_FEATURE, account: conversation.account, fallback_model: Llm::Models.default_model_for(LLM_FEATURE))
    @assistant = assistant
    @conversation = conversation
    @content = Cosmos::Llm::ConversationFaqContentService.new(assistant, conversation).generate
    @embedding_service = Cosmos::Llm::EmbeddingService.new(account_id: conversation.account_id)
  end

  def generate_suggestions
    return [] if no_human_interaction?

    generate.map { |faq| route_candidate(faq) }
  end

  private

  attr_reader :content, :conversation, :assistant, :embedding_service

  def no_human_interaction?
    conversation.first_reply_created_at.nil?
  end

  def route_candidate(faq)
    embedding = embedding_service.get_embedding(candidate_text(faq))

    faqs.each do |faq|
      combined_text = "#{faq['question']}: #{faq['answer']}"
      embedding = Cosmos::Llm::EmbeddingService.new.get_embedding(combined_text)
      similar_faqs = find_similar_faqs(embedding)

    suggestion = matching_record(open_suggestions_for_language, faq, embedding)
    matched_content = suggestion&.slice('question', 'answer')
    suggestion ||= assistant.faq_suggestions.create!(
      question: faq.fetch('question'),
      answer: faq.fetch('answer'),
      embedding: embedding,
      language: faq_language
    )

    attach_observation(suggestion, faq, matched_content)
  end

  def matching_record(relation, faq, embedding)
    likely_matches(relation, embedding).find { |record| same_faq?(faq, record) }
  end

  def likely_matches(relation, embedding)
    return [] unless relation.exists?

    ApplicationRecord.transaction do
      # Force an exact search because IVFFlat can miss matches after relation filters.
      # SET LOCAL keeps the planner change scoped to this transaction.
      ApplicationRecord.connection.execute('SET LOCAL enable_indexscan = off')
      relation
        .nearest_neighbors(:embedding, embedding, distance: 'cosine')
        .limit(MATCH_LIMIT)
        .select { |record| record.neighbor_distance < DISTANCE_THRESHOLD }
    end
  end

  def same_faq?(candidate, existing_record)
    comparison = {
      candidate: candidate.slice('question', 'answer'),
      existing: { question: existing_record.question, answer: existing_record.answer }
    }
    prompt = Cosmos::Llm::ConversationFaqPromptsService.same_faq
    faq_match_model = Llm::FeatureRouter.resolve(feature: 'conversation_faq_matching', account: conversation.account)[:model]
    response = instrument_llm_call(match_instrumentation_params(prompt, comparison, faq_match_model)) do
      chat(model: faq_match_model)
        .with_params(response_format: { type: 'json_object' })
        .with_instructions(prompt)
        .ask(comparison.to_json)
    end

    same_faq = JSON.parse(sanitize_json_response(response.content)).fetch('same_faq')
    raise TypeError, 'same_faq must be a boolean' unless [true, false].include?(same_faq)

    same_faq
  rescue JSON::ParserError, KeyError, TypeError, RubyLLM::Error => e
    Rails.logger.error "FAQ match failed: #{e.message}"
    raise
  end

  def attach_observation(suggestion, faq, matched_content)
    suggestion.with_lock do
      next unless suggestion.open?
      raise SuggestionChangedError if matched_content && suggestion.slice('question', 'answer') != matched_content

      existing_observation = suggestion.observations.find_by(conversation: conversation)
      next existing_observation if existing_observation

      observation = suggestion.observations.create!(
        conversation: conversation,
        generated_question: faq.fetch('question'),
        generated_answer: faq.fetch('answer'),
        language: faq_language,
        status: :attached
      )
      suggestion.update!(source_count: suggestion.source_count + 1)
      observation
    end
  end

  def discard_observation(faq)
    Cosmos::FaqObservation.find_or_create_by!(
      conversation: conversation,
      generated_question: faq.fetch('question'),
      generated_answer: faq.fetch('answer'),
      language: faq_language,
      status: :discarded
    )
  end

  def open_suggestions_for_language
    assistant.faq_suggestions.where(account_id: conversation.account_id).open.by_language(faq_language)
  end

  def dismissed_suggestions_for_language
    assistant.faq_suggestions.where(account_id: conversation.account_id).dismissed.by_language(faq_language)
  end

  def approved_faqs
    assistant.responses.approved
  end

  def candidate_text(faq)
    "#{faq.fetch('question')}: #{faq.fetch('answer')}"
  end

  def generate
    response = @client.chat(parameters: chat_parameters)
    parse_response(response)
  rescue OpenAI::Error => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    []
  end

  def chat_parameters
    account_language = @conversation.account.locale_english_name
    prompt = Cosmos::Llm::SystemPromptsService.conversation_faq_generator(account_language)

    {
      model: @model,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content: prompt
        },
        {
          role: 'user',
          content: content
        }
      ]
    }
  end

  def parse_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    return [] if content.nil?

    JSON.parse(content.strip).fetch('faqs', [])
  rescue JSON::ParserError => e
    Rails.logger.error "Error in parsing GPT processed response: #{e.message}"
    []
  end
end
end
