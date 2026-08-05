class Reports::MultiEntityScope
  pattr_initialize :account, :dimension_type, :ids

  def conversations
    case dimension_type.to_sym
    when :agent
      account.conversations.where(assignee_id: ids)
    when :inbox
      account.conversations.where(inbox_id: ids)
    when :team
      account.conversations.where(team_id: ids)
    when :label
      account.conversations.tagged_with(label_titles, any: true)
    end
  end

  def messages
    case dimension_type.to_sym
    when :inbox
      account.messages.where(inbox_id: ids)
    else
      account.messages.where(conversation_id: conversations.select(:id))
    end
  end

  def reporting_events
    case dimension_type.to_sym
    when :agent
      account.reporting_events.where(user_id: ids)
    when :inbox
      account.reporting_events.where(inbox_id: ids)
    else
      account.reporting_events.where(conversation_id: conversations.select(:id))
    end
  end

  private

  def label_titles
    @label_titles ||= account.labels.where(id: ids).pluck(:title)
  end
end
