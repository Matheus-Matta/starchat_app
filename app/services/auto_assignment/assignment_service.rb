class AutoAssignment::AssignmentService
  pattr_initialize [:inbox!]

  QUEUE_LOG_LIMIT = 50

  def perform_bulk_assignment(limit: 100)
    return 0 unless inbox.auto_assignment_v2_enabled?
    return 0 unless inbox.enable_auto_assignment?

    conversations = unassigned_conversations(limit).to_a
    return 0 if conversations.empty?
    return 0 if inbox.available_agents.empty?

    assigned_count = 0
    conversations.each do |conversation|
      assigned_count += 1 if perform_for_conversation(conversation)
    end
    assigned_count
  end

  private

  def perform_for_conversation(conversation)
    return false unless assignable?(conversation)

    responsible_agent = find_responsible_agent(conversation)
    if responsible_agent
      @last_available_agent_user_ids = [responsible_agent.id]
      return assign_conversation(conversation, responsible_agent)
    end

    agent = find_available_agent
    return false unless agent

    assign_conversation(conversation, agent)
  end

  def assignable?(conversation)
    conversation.status == 'open' &&
      conversation.assignee_id.nil?
  end

  def find_responsible_agent(conversation)
    return nil unless prioritize_responsible_agent?

    contact = conversation.contact
    return nil if contact&.responsible_agents&.empty?

    contact.responsible_agents.each do |agent|
      next unless agent.accounts.exists?(id: inbox.account_id)

      candidates = inbox.available_agents.select { |member| member.user_id == agent.id }
      next if candidates.empty?

      candidates = filter_agents_by_rate_limit(candidates)
      if respond_to?(:filter_agents_by_capacity, true) && respond_to?(:capacity_filtering_enabled?, true) && capacity_filtering_enabled?
        candidates = filter_agents_by_capacity(candidates)
      end

      return candidates.first&.user if candidates.any?
    end

    nil
  end

  def prioritize_responsible_agent?
    return false unless inbox.enable_auto_assignment?

    settings = inbox.account.settings || {}
    settings.fetch('prioritize_responsible_agent', false)
  end

  def unassigned_conversations(limit)
    scope = inbox.conversations.unassigned.open

    # Skip stale backlog with no activity beyond the age threshold
    policy = inbox.assignment_policy
    scope = apply_age_exclusions(scope, age_exclusion_hours(policy))

    # Apply conversation priority using assignment policy if available
    scope = if policy&.longest_waiting?
              scope.reorder(last_activity_at: :asc, created_at: :asc)
            else
              scope.reorder(created_at: :asc)
            end

    scope.limit(limit)
  end

  def find_available_agent
    agents_raw = inbox.available_agents
    agents = filter_agents_by_rate_limit(agents_raw)
  end

  def age_exclusion_hours(policy)
    return policy.exclude_older_than_hours if policy

    AssignmentPolicy::DEFAULT_EXCLUDE_OLDER_THAN_HOURS
  end

  def apply_age_exclusions(scope, hours_threshold)
    return scope if hours_threshold.blank?

    hours = hours_threshold.to_i
    return scope unless hours.positive?

    # Use last_activity_at so reopened/active conversations aren't excluded by their original created_at
    scope.where('conversations.last_activity_at >= ?', hours.hours.ago)
  end

  def find_available_agent(conversation = nil)
    agents = filter_agents_by_team(inbox.available_agents, conversation)
    return nil if agents.nil?

    agents = filter_agents_by_rate_limit(agents)
    return nil if agents.empty?

    @last_queue_before = round_robin_selector.queue_snapshot(limit: QUEUE_LOG_LIMIT)
    @last_available_agent_user_ids = agents.map do |agent_member|
      agent_member.respond_to?(:user_id) ? agent_member.user_id : agent_member.id
    end
    selected = round_robin_selector.select_agent(agents)
    @last_queue_after = round_robin_selector.queue_snapshot(limit: QUEUE_LOG_LIMIT)
    selected
  end

  def filter_agents_by_team(agents, conversation)
    return agents if conversation&.team_id.blank?

    team = conversation.team
    return nil if team.blank? || team.allow_auto_assign.blank?

    team_member_ids = team.members.ids
    agents.where(user_id: team_member_ids)
  end

  def filter_agents_by_rate_limit(agents)
    agents.select do |agent_member|
      rate_limiter = build_rate_limiter(agent_member.user)
      rate_limiter.within_limit?
    end
  end

  def assign_conversation(conversation, agent)
    return false unless claim_and_assign(conversation, agent)

    conversation.reload

    rate_limiter = build_rate_limiter(agent)
    rate_limiter.track_assignment(conversation)

    log_assignment_audit(conversation, agent)
    dispatch_assignment_event(conversation, agent)
    true
  end

  # Atomically claim the row so two bulk runs that overlap (the in-flight gate
  # is best-effort and can lapse on TTL) can't both assign the same conversation.
  def claim_and_assign(conversation, agent)
    Current.executed_by = inbox.assignment_policy || inbox

    Conversation.transaction do
      locked = inbox.conversations
                    .where(id: conversation.id, assignee_id: nil)
                    .lock('FOR UPDATE SKIP LOCKED')
                    .first
      next false unless locked

      locked.update!(assignee: agent)
      true
    end
  ensure
    Current.executed_by = nil
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
