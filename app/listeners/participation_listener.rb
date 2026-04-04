class ParticipationListener < BaseListener
  include Events::Types

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    return if conversation.assignee_id.blank?

    conversation.conversation_participants.find_or_create_by!(user_id: conversation.assignee_id)
    add_responsible_agents_as_participants(conversation, account)
  # We have observed race conditions triggering these errors
  # example: Assignment happening via automation, while auto assignment is also configured.
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    Rails.logger.warn "Failed to create conversation participant for account #{conversation.account.id} " \
                      ": user #{conversation.assignee_id} : conversation #{conversation.id}"
  end

  private

  def add_responsible_agents_as_participants(conversation, account)
    return unless account.prioritize_responsible_agent

    responsible_agents = conversation.contact&.responsible_agents
    return if responsible_agents.blank?

    responsible_agents.each do |agent|
      conversation.conversation_participants.find_or_create_by!(user_id: agent.id)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      Rails.logger.warn "Failed to add responsible agent #{agent.id} as participant " \
                        "for conversation #{conversation.id}"
    end
  end
end
