class Cosmos::ConversationCompletionService
  def initialize(account:, conversation_display_id:)
    @account = account
    @conversation_display_id = conversation_display_id
  end

  def perform
    { complete: false, reason: nil }
  end
end
