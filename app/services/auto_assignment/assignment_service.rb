class AutoAssignment::AssignmentService
  pattr_initialize [:inbox!]

  QUEUE_LOG_LIMIT = 50

  def perform_bulk_assignment(limit: 100)
    return 0 unless inbox.auto_assignment_v2_enabled?

    assigned_count = 0

    unassigned_conversations(limit).each do |conversation|
      assigned_count += 1 if perform_for_conversation(conversation)
    end

    assigned_count
  end

  private

  def perform_for_conversation(conversation)
    return false unless assignable?(conversation)

    agent = find_available_agent
    return false unless agent

    assign_conversation(conversation, agent)
  end

  def assignable?(conversation)
    conversation.status == 'open' &&
      conversation.assignee_id.nil?
  end

  def unassigned_conversations(limit)
    scope = inbox.conversations.unassigned.open

    scope = if assignment_config['conversation_priority'].to_s == 'longest_waiting'
              scope.reorder(last_activity_at: :asc, created_at: :asc)
            else
              scope.reorder(created_at: :asc)
            end

    scope.limit(limit)
  end

  def find_available_agent
    agents_raw = inbox.available_agents
    agents = filter_agents_by_rate_limit(agents_raw)
    return nil if agents.empty?

    @last_queue_before = round_robin_selector.queue_snapshot(limit: QUEUE_LOG_LIMIT)
    @last_available_agent_user_ids = agents.map do |agent_member|
      agent_member.respond_to?(:user_id) ? agent_member.user_id : agent_member.id
    end
    selected = round_robin_selector.select_agent(agents)
    @last_queue_after = round_robin_selector.queue_snapshot(limit: QUEUE_LOG_LIMIT)
    selected
  end

  def filter_agents_by_rate_limit(agents)
    agents.select do |agent_member|
      rate_limiter = build_rate_limiter(agent_member.user)
      rate_limiter.within_limit?
    end
  end

  def assign_conversation(conversation, agent)
    conversation.update!(assignee: agent)

    rate_limiter = build_rate_limiter(agent)
    rate_limiter.track_assignment(conversation)

    log_assignment_audit(conversation, agent)
    dispatch_assignment_event(conversation, agent)
    true
  end

  def dispatch_assignment_event(conversation, agent)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::ASSIGNEE_CHANGED,
      Time.zone.now,
      conversation: conversation,
      user: agent
    )
  end

  def build_rate_limiter(agent)
    AutoAssignment::RateLimiter.new(inbox: inbox, agent: agent)
  end

  def round_robin_selector
    @round_robin_selector ||= AutoAssignment::RoundRobinSelector.new(inbox: inbox)
  end

  def log_assignment_audit(conversation, agent)
    Starchat::AuditLog.create(
      auditable: conversation,
      action: 'auto_assign',
      user: agent,
      associated: conversation.account,
      audited_changes: {
        assignee_id: [nil, agent.id],
        inbox_id: conversation.inbox_id,
        conversation_display_id: conversation.display_id,
        conversation_status: conversation.status,
        assignment_source: 'auto_assignment_v2',
        available_agent_user_ids: @last_available_agent_user_ids,
        queue_before: @last_queue_before,
        queue_after: @last_queue_after,
        queue_before_size: @last_queue_before&.size,
        queue_after_size: @last_queue_after&.size
      }.compact
    )
  rescue StandardError => e
    Rails.logger.error("Auto-assignment audit log failed for conversation #{conversation.id}: #{e.class} #{e.message}")
  end

  def assignment_config
    @assignment_config ||= inbox.auto_assignment_config || {}
  end
end

AutoAssignment::AssignmentService.prepend_mod_with('AutoAssignment::AssignmentService')
