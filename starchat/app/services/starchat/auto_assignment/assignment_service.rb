module Starchat::AutoAssignment::AssignmentService
  QUEUE_LOG_LIMIT = 50

  private

  # Override assignment config to use policy if available
  def assignment_config
    return super unless policy

    config = {
      'conversation_priority' => policy.conversation_priority,
      'fair_distribution_limit' => policy.fair_distribution_limit,
      'fair_distribution_window' => policy.fair_distribution_window,
      'balanced' => policy.balanced?
    }

    if policy.equal_distribution?
      config['equal_distribution_enabled'] = true
      config['equal_distribution_window_hours'] = policy.equal_distribution_window_hours
      config['equal_distribution_balance_threshold'] = policy.equal_distribution_balance_threshold
    end

    config.compact
  end

  def perform_for_conversation(conversation)
    return false if conversation_team_blocks_assignment?(conversation)

    super
  end

  # Extend agent finding to add capacity checks
  def find_available_agent
    agents = filter_agents_by_rate_limit(inbox.available_agents)
    agents = filter_agents_by_capacity(agents) if capacity_filtering_enabled?
    return nil if agents.empty?

    @last_queue_before = round_robin_selector.queue_snapshot(limit: QUEUE_LOG_LIMIT)
    @last_available_agent_user_ids = agents.map do |agent_member|
      agent_member.respond_to?(:user_id) ? agent_member.user_id : agent_member.id
    end
    selector = resolve_selector
    selected = selector.select_agent(agents)
    @last_queue_after = round_robin_selector.queue_snapshot(limit: QUEUE_LOG_LIMIT)
    selected
  end

  def conversation_team_blocks_assignment?(conversation)
    return false if conversation.team_id.blank?

    team = conversation.team
    team.present? && team.allow_auto_assign == false
  end

  def filter_agents_by_capacity(agents)
    return agents unless capacity_filtering_enabled?

    capacity_service = Starchat::AutoAssignment::CapacityService.new
    agents.select { |agent_member| capacity_service.agent_has_capacity?(agent_member.user, inbox) }
  end

  def capacity_filtering_enabled?
    account.feature_enabled?('assignment_v2') &&
      account.account_users.joins(:agent_capacity_policy).exists?
  end

  # Determina qual seletor usar com base na política:
  #   1. policy.equal_distribution?          → EqualDistributionSelector via configuração da política
  #      (menor carga dentro da janela de tempo; com fallback para round-robin se
  #       a dispersão de carga estiver abaixo do limiar configurado pela política)
  #   2. inbox_assignment_policy.equal_distribution_enabled (legado)
  #                                          → EqualDistributionSelector via configuração por inbox
  #   3. balanced                            → BalancedSelector (menor carga total, sem janela)
  #   4. padrão                              → RoundRobinSelector (fila circular Redis)
  def resolve_selector
    if policy&.equal_distribution?
      policy_equal_distribution_selector
    elsif inbox_assignment_policy&.equal_distribution_enabled?
      inbox_equal_distribution_selector
    elsif policy&.balanced?
      balanced_selector
    else
      round_robin_selector
    end
  end

  def round_robin_selector
    @round_robin_selector ||= AutoAssignment::RoundRobinSelector.new(inbox: inbox)
  end

  def balanced_selector
    @balanced_selector ||= Starchat::AutoAssignment::BalancedSelector.new(inbox: inbox)
  end

  def policy_equal_distribution_selector
    @policy_equal_distribution_selector ||= Starchat::AutoAssignment::EqualDistributionSelector.new(
      inbox: inbox,
      window_hours: policy.equal_distribution_window_hours,
      balance_threshold: policy.equal_distribution_balance_threshold,
      round_robin_fallback: round_robin_selector
    )
  end

  # Legado: igual distribuição configurada por inbox
  def inbox_equal_distribution_selector
    @inbox_equal_distribution_selector ||= Starchat::AutoAssignment::EqualDistributionSelector.new(
      inbox: inbox,
      window_hours: inbox_assignment_policy.equal_distribution_window_hours,
      balance_threshold: inbox_assignment_policy.equal_distribution_balance_threshold,
      round_robin_fallback: round_robin_selector
    )
  end

  # Alias para compatibilidade de código existente
  alias equal_distribution_selector inbox_equal_distribution_selector

  def inbox_assignment_policy
    @inbox_assignment_policy ||= inbox.inbox_assignment_policy
  end

  def policy
    return nil unless inbox.enable_auto_assignment?

    @policy ||= inbox.assignment_policy
  end

  def account
    inbox.account
  end

  # Override to apply exclusion rules
  def unassigned_conversations(limit)
    scope = inbox.conversations.unassigned.open

    # Apply exclusion rules from capacity policy or assignment policy
    scope = apply_exclusion_rules(scope)

    # Apply conversation priority using enum methods if policy exists
    scope = if policy&.longest_waiting?
              scope.reorder(last_activity_at: :asc, created_at: :asc)
            else
              scope.reorder(created_at: :asc)
            end

    scope.limit(limit)
  end

  def apply_exclusion_rules(scope)
    capacity_policy = inbox.inbox_capacity_limits.first&.agent_capacity_policy
    return scope unless capacity_policy

    exclusion_rules = capacity_policy.exclusion_rules || {}
    scope = apply_label_exclusions(scope, exclusion_rules['excluded_labels'])
    apply_age_exclusions(scope, exclusion_rules['exclude_older_than_hours'])
  end

  def apply_label_exclusions(scope, excluded_labels)
    return scope if excluded_labels.blank?

    scope.tagged_with(excluded_labels, exclude: true, on: :labels)
  end

  def apply_age_exclusions(scope, hours_threshold)
    return scope if hours_threshold.blank?

    hours = hours_threshold.to_i
    return scope unless hours.positive?

    scope.where('conversations.created_at >= ?', hours.hours.ago)
  end
end
