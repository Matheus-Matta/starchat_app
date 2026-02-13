class AutoAssignment::RoundRobinSelector
  pattr_initialize [:inbox!]

  def select_agent(available_agents)
    return nil if available_agents.empty?

    agent_user_ids = available_agents.map(&:user_id).map(&:to_s)
    round_robin_service.available_agent(allowed_agent_ids: agent_user_ids)
  end

  def queue_snapshot(limit: nil)
    round_robin_service.queue_snapshot(limit: limit)
  end

  private

  def round_robin_service
    @round_robin_service ||= AutoAssignment::InboxRoundRobinService.new(inbox: inbox)
  end
end
