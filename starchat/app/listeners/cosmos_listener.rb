class CosmosListener < BaseListener
  include ::Events::Types

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    assistant = conversation.inbox.cosmos_assistant

    return unless conversation.inbox.cosmos_active?

    Cosmos::Llm::ContactNotesService.new(assistant, conversation).generate_and_update_notes if assistant.config['feature_memory'].present?
    Cosmos::Llm::ConversationFaqJob.perform_later(conversation, assistant) if assistant.config['feature_faq'].present?
  end
end
