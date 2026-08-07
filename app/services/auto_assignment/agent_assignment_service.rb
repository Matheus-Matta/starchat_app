class AutoAssignment::AgentAssignmentService
  # Allowed agent ids: array
  # This is the list of agents from which an agent can be assigned to this conversation
  # examples: Agents with assignment capacity, Agents who are members of a team etc
  pattr_initialize [:conversation!, :allowed_agent_ids!]

  QUEUE_LOG_LIMIT = 50

  def find_assignee
    round_robin_manage_service.available_agent(allowed_agent_ids: allowed_online_agent_ids)
  end

  def perform
    queue_before = queue_snapshot
    new_assignee = find_assignee
    return unless new_assignee

    return unless conversation.update(assignee: new_assignee)

    queue_after = queue_snapshot
    log_assignment_audit(new_assignee, queue_before: queue_before, queue_after: queue_after)
  end

  private

  def online_agent_ids
    online_agents = OnlineStatusTracker.get_available_users(conversation.account_id)
    online_agents.select { |_key, value| value.eql?('online') }.keys if online_agents.present?
  end

  def allowed_online_agent_ids
    # We want to perform roundrobin only over online agents
    # Hence taking an intersection of online agents and allowed member ids

    # the online user ids are string, since its from redis, allowed member ids are integer, since its from active record
    @allowed_online_agent_ids ||= online_agent_ids & allowed_agent_ids&.map(&:to_s)
  end

  def round_robin_manage_service
    @round_robin_manage_service ||= AutoAssignment::InboxRoundRobinService.new(inbox: conversation.inbox)
  end

  def queue_snapshot
    round_robin_manage_service.queue_snapshot(limit: QUEUE_LOG_LIMIT)
  end

  def round_robin_key
    format(::Redis::Alfred::ROUND_ROBIN_AGENTS, inbox_id: conversation.inbox_id)
  end

  def log_assignment_audit(new_assignee, queue_before:, queue_after:)
    Starchat::AuditLog.create(
      auditable: conversation,
      action: 'auto_assign',
      user: new_assignee,
      associated: conversation.account,
      audited_changes: {
        assignee_id: [nil, new_assignee.id],
        inbox_id: conversation.inbox_id,
        conversation_display_id: conversation.display_id,
        conversation_status: conversation.status,
        assignment_source: 'auto_assignment_legacy',
        allowed_agent_ids: allowed_agent_ids,
        allowed_online_agent_ids: allowed_online_agent_ids,
        online_agent_ids: online_agent_ids,
        queue_before: queue_before,
        queue_after: queue_after,
        queue_before_size: queue_before&.size,
        queue_after_size: queue_after&.size
      }.compact
    )
  rescue StandardError => e
    Rails.logger.error("Auto-assignment audit log failed for conversation #{conversation.id}: #{e.class} #{e.message}")
  end
end
