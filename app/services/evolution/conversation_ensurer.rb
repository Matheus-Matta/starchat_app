module Evolution
  module ConversationEnsurer
    module_function

    def ensure!(inbox:, contact_inbox:)
      ActiveRecord::Base.transaction(requires_new: true) do
        # Try to find an existing conversation
        Rails.logger.info "[ConversationEnsurer] Checking ContactInbox ##{contact_inbox.id}. LockToSingle: #{inbox.lock_to_single_conversation?}"

        conv = if inbox.lock_to_single_conversation?
                 ::Conversation.where(contact_inbox_id: contact_inbox.id)
                               .order(updated_at: :desc).first
               else
                 # Find any conversation that is NOT resolved (open, pending, snoozed)
                 ::Conversation.where(contact_inbox_id: contact_inbox.id)
                               .where.not(status: :resolved)
                               .order(updated_at: :desc).first
               end

        if conv.present?
          Rails.logger.info "[ConversationEnsurer] Found existing conversation ##{conv.id} status: #{conv.status}"
          return conv
        end

        # DEBUG: Dump existing conversations to understand why we missed
        existing_debug = ::Conversation.where(contact_inbox_id: contact_inbox.id).pluck(:id, :status)
        Rails.logger.info "[ConversationEnsurer] NO MATCH found. Existing conversations for ContactInbox ##{contact_inbox.id}: #{existing_debug.inspect}"

        # Should we reopen a resolved conversation?
        if inbox.lock_to_single_conversation?
          last_conv = ::Conversation.where(contact_inbox_id: contact_inbox.id)
                                    .order(updated_at: :desc).first
          if last_conv&.resolved? && last_conv.updated_at >= 48.hours.ago
            Rails.logger.info "[ConversationEnsurer] Reopening resolved conversation ##{last_conv.id}"
            last_conv.open!
            return last_conv
          end
        end

        Rails.logger.info "[ConversationEnsurer] Creating NEW conversation..."
        permitted = ActionController::Parameters.new(
          account_id: inbox.account_id,
          inbox_id: inbox.id,
          additional_attributes: {}
        ).permit!

        ::ConversationBuilder.new(contact_inbox: contact_inbox, params: permitted).perform
      end
    end
  end
end
