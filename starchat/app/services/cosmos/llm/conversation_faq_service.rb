class Cosmos::Llm::ConversationFaqService < Llm::BaseOpenAiService
  DISTANCE_THRESHOLD = 0.3
  LLM_FEATURE = 'conversation_faq_generation'.freeze

  def initialize(assistant, conversation)
    super(feature: LLM_FEATURE, account: conversation.account, fallback_model: Llm::Models.default_model_for(LLM_FEATURE))
    @assistant = assistant
    @conversation = conversation
    @content = conversation_faq_content
  end

  # Generates and deduplicates FAQs from conversation content
  # Skips processing if there was no human interaction
  def generate_and_deduplicate
    return [] if no_human_interaction?

    new_faqs = generate
    return [] if new_faqs.empty?

    duplicate_faqs, unique_faqs = find_and_separate_duplicates(new_faqs)
    save_new_faqs(unique_faqs)
    log_duplicate_faqs(duplicate_faqs) if Rails.env.development?
  end

  private

  attr_reader :content, :conversation, :assistant

  def conversation_faq_content
    [
      "Conversation ID: ##{conversation.display_id}",
      "Channel: #{conversation.inbox.channel.name}",
      'Message History:',
      conversation_faq_messages
    ].join("\n")
  end

  def conversation_faq_messages
    messages = conversation
               .messages
               .where(message_type: %i[incoming outgoing], private: false)
               .order(created_at: :asc)

    return "No messages in this conversation\n" if messages.empty?

    messages.filter_map { |message| format_conversation_faq_message(message) }.join
  end

  def format_conversation_faq_message(message)
    return unless faq_source_message?(message)

    content = message.content_for_llm
    return if content.blank?

    sender = human_support_reply?(message) ? 'Support Agent' : 'User'
    "#{sender}: #{content}\n"
  end

  def faq_source_message?(message)
    return true if message.incoming? && message.sender_type == 'Contact'

    human_support_reply?(message)
  end

  def human_support_reply?(message)
    return false unless message.outgoing?
    return false if message.content_attributes['automation_rule_id'].present?
    return false if message.additional_attributes['campaign_id'].present?

    message.sender_type == 'User' || message.content_attributes['external_echo'].present?
  end

  def no_human_interaction?
    conversation.first_reply_created_at.nil?
  end

  def find_and_separate_duplicates(faqs)
    duplicate_faqs = []
    unique_faqs = []

    faqs.each do |faq|
      combined_text = "#{faq['question']}: #{faq['answer']}"
      embedding = Cosmos::Llm::EmbeddingService.new.get_embedding(combined_text)
      similar_faqs = find_similar_faqs(embedding)

      if similar_faqs.any?
        duplicate_faqs << { faq: faq, similar_faqs: similar_faqs }
      else
        unique_faqs << faq
      end
    end

    [duplicate_faqs, unique_faqs]
  end

  def find_similar_faqs(embedding)
    similar_faqs = assistant
                   .responses
                   .nearest_neighbors(:embedding, embedding, distance: 'cosine')
    Rails.logger.debug(similar_faqs.map { |faq| [faq.question, faq.neighbor_distance] })
    similar_faqs.select { |record| record.neighbor_distance < DISTANCE_THRESHOLD }
  end

  def save_new_faqs(faqs)
    faqs.map do |faq|
      assistant.responses.create!(
        question: faq['question'],
        answer: faq['answer'],
        status: 'pending',
        documentable: conversation
      )
    end
  end

  def log_duplicate_faqs(duplicate_faqs)
    return if duplicate_faqs.empty?

    Rails.logger.info "Found #{duplicate_faqs.length} duplicate FAQs:"
    duplicate_faqs.each do |duplicate|
      Rails.logger.info(
        "Q: #{duplicate[:faq]['question']}\n" \
        "A: #{duplicate[:faq]['answer']}\n\n" \
        "Similar existing FAQs: #{duplicate[:similar_faqs].map { |f| "Q: #{f.question} A: #{f.answer}" }.join(', ')}"
      )
    end
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
