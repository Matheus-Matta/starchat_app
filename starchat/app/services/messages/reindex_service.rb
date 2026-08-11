class Messages::ReindexService
  pattr_initialize [:account!]

  def perform
    return unless StarchatsApp.advanced_search_allowed?

    reindex_messages
  end

  private

  def reindex_messages
    account.messages.reindex(mode: :async)
  end
end
