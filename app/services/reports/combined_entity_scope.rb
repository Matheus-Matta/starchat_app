class Reports::CombinedEntityScope
  pattr_initialize :account, :agent_ids, :team_ids, :inbox_ids

  def conversations
    combine(conversation_scopes, account.conversations)
  end

  def messages
    combine(message_scopes, account.messages)
  end

  def reporting_events
    combine(reporting_event_scopes, account.reporting_events)
  end

  private

  def conversation_scopes
    scopes = []
    scopes << account.conversations.where(assignee_id: agent_ids) if agent_ids.present?
    scopes << account.conversations.where(team_id: team_ids) if team_ids.present?
    scopes << account.conversations.where(inbox_id: inbox_ids) if inbox_ids.present?
    scopes
  end

  def message_scopes
    scopes = []
    scopes << account.messages.where(sender_type: 'User', sender_id: agent_ids) if agent_ids.present?
    scopes << account.messages.where(conversation_id: team_conversation_ids) if team_ids.present?
    scopes << account.messages.where(inbox_id: inbox_ids) if inbox_ids.present?
    scopes
  end

  def reporting_event_scopes
    scopes = []
    scopes << account.reporting_events.where(user_id: agent_ids) if agent_ids.present?
    scopes << account.reporting_events.where(conversation_id: team_conversation_ids) if team_ids.present?
    scopes << account.reporting_events.where(inbox_id: inbox_ids) if inbox_ids.present?
    scopes
  end

  def team_conversation_ids
    account.conversations.where(team_id: team_ids).select(:id)
  end

  # Combines per-dimension scopes with OR, so e.g. selecting Agent A and Team B
  # returns conversations assigned to A OR belonging to B (not their intersection).
  def combine(scopes, fallback)
    return fallback.none if scopes.empty?

    scopes.reduce { |memo, scope| memo.or(scope) }
  end
end
