module Evolution
  module ConversationEnsurer
    module_function

    def ensure!(inbox:, contact_inbox:)
      ActiveRecord::Base.transaction(requires_new: true) do
        find_existing_conversation(inbox, contact_inbox) || create_new_conversation(inbox, contact_inbox)
      end
    end

    private_class_method def find_existing_conversation(inbox, contact_inbox)
      if inbox.lock_to_single_conversation?
        find_and_reopen_latest_conversation(contact_inbox)
      else
        find_active_conversation(contact_inbox)
      end
    end

    private_class_method def find_latest_conversation(contact_inbox)
      ::Conversation.where(contact_inbox_id: contact_inbox.id)
                    .order(updated_at: :desc)
                    .first
    end

    private_class_method def find_active_conversation(contact_inbox)
      ::Conversation.where(contact_inbox_id: contact_inbox.id)
                    .where.not(status: :resolved)
                    .order(updated_at: :desc)
                    .first
    end

    # Reuses the contact's last conversation when the inbox is locked to a single
    # thread. If that conversation was resolved recently, it's reopened instead of
    # being handed back stuck in `resolved`.
    private_class_method def find_and_reopen_latest_conversation(contact_inbox)
      conversation = find_latest_conversation(contact_inbox)
      return unless conversation

      conversation.open! if conversation.resolved? && conversation.updated_at >= 48.hours.ago
      conversation
    end

    private_class_method def create_new_conversation(inbox, contact_inbox)
      params = ActionController::Parameters.new(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        status: 'open',
        additional_attributes: {}
      ).permit!

      ::ConversationBuilder.new(contact_inbox: contact_inbox, params: params).perform
    end
  end
end
