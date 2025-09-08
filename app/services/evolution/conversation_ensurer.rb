# frozen_string_literal: true

module Evolution
  module ConversationEnsurer
    module_function

    def ensure!(inbox:, contact_inbox:)
      ActiveRecord::Base.transaction(requires_new: true) do
        ::ContactInbox.lock.where(id: contact_inbox.id).pluck(:id)
        if inbox.lock_to_single_conversation?
          conv = ::Conversation.where(contact_inbox_id: contact_inbox.id)
                               .order(updated_at: :desc).first
          return conv if conv.present?
        end
        conv = ::Conversation.where(contact_inbox_id: contact_inbox.id, status: :open)
                             .order(updated_at: :desc).first
        return conv if conv.present?
        last_conv = ::Conversation.where(contact_inbox_id: contact_inbox.id)
                                  .order(updated_at: :desc).first
        if last_conv&.resolved? && last_conv.updated_at >= 48.hours.ago
          last_conv.open!
          return last_conv
        end
        permitted = ActionController::Parameters.new(
          account_id:            inbox.account_id,
          inbox_id:              inbox.id,
          additional_attributes: {}
        ).permit!
        ::ConversationBuilder.new(contact_inbox:, params: permitted).perform
      end
    end
  end
end
