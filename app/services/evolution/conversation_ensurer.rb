module Evolution
  module ConversationEnsurer
    module_function

    def ensure!(inbox:, contact_inbox:)
      ActiveRecord::Base.transaction(requires_new: true) do
        conversation = find_existing_conversation(inbox, contact_inbox) ||
                       reopen_recent_resolved_conversation(inbox, contact_inbox) ||
                       create_new_conversation(inbox, contact_inbox)

        conversation
      end
    end

    private_class_method def find_existing_conversation(inbox, contact_inbox)
      if inbox.lock_to_single_conversation?
        find_latest_conversation(contact_inbox)
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

    private_class_method def reopen_recent_resolved_conversation(inbox, contact_inbox)
      return unless inbox.lock_to_single_conversation?

      last_conversation = find_latest_conversation(contact_inbox)
      return unless last_conversation&.resolved?
      return unless last_conversation.updated_at >= 48.hours.ago

      last_conversation.open!
      last_conversation
    end

    private_class_method def create_new_conversation(inbox, contact_inbox)
      params = ActionController::Parameters.new(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        additional_attributes: {}
      ).permit!

      ::ConversationBuilder.new(contact_inbox: contact_inbox, params: params).perform
    end
  end
end
