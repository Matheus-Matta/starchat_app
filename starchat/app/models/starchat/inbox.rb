module Starchat::Inbox
  def member_ids_with_assignment_capacity
    return super unless enable_auto_assignment?
    return filter_by_capacity(available_agents).map(&:user_id) if auto_assignment_v2_enabled?

    max_assignment_limit = auto_assignment_config['max_assignment_limit']
    overloaded_agent_ids = max_assignment_limit.present? ? get_agent_ids_over_assignment_limit(max_assignment_limit) : []
    super - overloaded_agent_ids
  end

  def active_bot?
    super || cosmos_active?
  end

  def cosmos_active?
    cosmos_assistant.present? && more_responses?
  end

  # The incoming_call and inbox_connection_update notifications use the inbox as
  # their primary_actor, and Notification#primary_actor_data calls push_event_data
  # on it. Without this the dispatch raised NoMethodError, which the caller's
  # rescue swallowed into a log line — so those notifications never reached agents.
  def push_event_data
    {
      id: id,
      name: name,
      channel_type: channel_type
    }
  end

  private

  def more_responses?
    account.usage_limits[:cosmos][:responses][:current_available].positive?
  end

  def get_agent_ids_over_assignment_limit(limit)
    conversations
      .open
      .where(account_id: account_id)
      .select(:assignee_id)
      .group(:assignee_id)
      .having("count(*) >= #{limit.to_i}")
      .filter_map(&:assignee_id)
  end

  def ensure_valid_max_assignment_limit
    return if auto_assignment_config['max_assignment_limit'].blank?
    return if auto_assignment_config['max_assignment_limit'].to_i.positive?

    errors.add(:auto_assignment_config, 'max_assignment_limit must be greater than 0')
  end
end
