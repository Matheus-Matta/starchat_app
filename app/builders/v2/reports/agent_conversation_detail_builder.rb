class V2::Reports::AgentConversationDetailBuilder
  include DateRangeHelper
  pattr_initialize [:account!, :agent!, :params!]

  def build
    { rows: rows, totals: totals }
  end

  private

  def rows
    @rows ||= conversations.map { |conversation| build_row(conversation) }
  end

  def totals
    {
      conversations_count: rows.size,
      incoming_messages_count: rows.sum { |row| row[:incoming_messages_count] },
      outgoing_messages_count: rows.sum { |row| row[:outgoing_messages_count] },
      avg_first_response_time: average(rows.filter_map { |row| row[:first_response_time] }),
      avg_reply_time: average(rows.filter_map { |row| row[:reply_time] }),
      avg_resolution_time: average(rows.filter_map { |row| row[:resolution_time] })
    }
  end

  def build_row(conversation)
    {
      display_id: conversation.display_id,
      contact_name: conversation.contact&.name,
      status: conversation.status,
      created_at: conversation.created_at,
      incoming_messages_count: incoming_messages_by_conversation[conversation.id] || 0,
      outgoing_messages_count: outgoing_messages_by_conversation[conversation.id] || 0,
      first_response_time: first_response_by_conversation[conversation.id],
      reply_time: reply_time_by_conversation[conversation.id],
      resolution_time: resolution_time_by_conversation[conversation.id],
      conversation_url: conversation_url(conversation)
    }
  end

  def conversations
    @conversations ||= account.conversations.where(assignee_id: agent.id, created_at: range).order(:created_at)
  end

  def conversation_ids
    @conversation_ids ||= conversations.map(&:id)
  end

  def value_key
    @value_key ||= use_business_hours? ? :value_in_business_hours : :value
  end

  def use_business_hours?
    ActiveModel::Type::Boolean.new.cast(params[:business_hours])
  end

  def reporting_events
    @reporting_events ||= ReportingEvent.where(account: account, conversation_id: conversation_ids)
  end

  # A conversation only ever gets one `first_response` event, but it can be
  # resolved (and reopened) more than once, so `to_h` keeps the latest resolution.
  def first_response_by_conversation
    @first_response_by_conversation ||= reporting_events.where(name: 'first_response').pluck(:conversation_id, value_key).to_h
  end

  def resolution_time_by_conversation
    @resolution_time_by_conversation ||= reporting_events.where(name: 'conversation_resolved').pluck(:conversation_id, value_key).to_h
  end

  def reply_time_by_conversation
    @reply_time_by_conversation ||= reporting_events.where(name: 'reply_time').group(:conversation_id).average(value_key)
  end

  def messages_by_conversation
    @messages_by_conversation ||= account.messages.where(conversation_id: conversation_ids).reorder(nil)
  end

  def incoming_messages_by_conversation
    @incoming_messages_by_conversation ||= messages_by_conversation.incoming.group(:conversation_id).count
  end

  def outgoing_messages_by_conversation
    @outgoing_messages_by_conversation ||= messages_by_conversation.outgoing.group(:conversation_id).count
  end

  def conversation_url(conversation)
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
  end

  def average(values)
    return nil if values.empty?

    values.sum.to_f / values.size
  end
end
